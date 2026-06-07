import SwiftUI
import MapKit
import CoreLocation

struct RoutePlannerMapView: UIViewRepresentable {
    @Binding var waypoints: [CLLocation]
    @Binding var resolvedRoute: [CLLocation]
    var displayMode: RouteMapDisplayMode = .standard
    var onWaypointsWillChange: (([CLLocation]) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = displayMode.mapType
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.userTrackingMode = .follow

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        let pointDragGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePointDrag(_:)))
        pointDragGesture.delegate = context.coordinator
        pointDragGesture.minimumNumberOfTouches = 1
        pointDragGesture.maximumNumberOfTouches = 1
        pointDragGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(pointDragGesture)
        context.coordinator.requestLocationAccess(for: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.mapType = displayMode.mapType
        context.coordinator.syncRoute(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {
        var parent: RoutePlannerMapView
        private let locationManager = CLLocationManager()
        private var waypointSignature = ""
        private var renderedRouteSignature = ""
        private var activeRouteRequestSignature = ""
        private var completedRouteRequestSignature = ""
        private var segmentCache: [String: [CLLocation]] = [:]
        private var routeRetryCounts: [String: Int] = [:]
        private weak var mapView: MKMapView?
        private var hasPositionedInitialRegion = false
        private var hasPositionedOnUserLocation = false
        private var directionsTask: Task<Void, Never>?
        private var retryTask: Task<Void, Never>?
        private var draggedWaypointIndex: Int?

        init(parent: RoutePlannerMapView) {
            self.parent = parent
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }

        deinit {
            directionsTask?.cancel()
            retryTask?.cancel()
        }

        func requestLocationAccess(for mapView: MKMapView) {
            self.mapView = mapView
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.requestLocation()
            case .denied, .restricted:
                positionInitialRegion(on: mapView, userCoordinate: nil)
            @unknown default:
                positionInitialRegion(on: mapView, userCoordinate: nil)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            guard nearestWaypointIndex(to: point, in: mapView) == nil else { return }
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let location = CLLocation(
                coordinate: coordinate,
                altitude: 0,
                horizontalAccuracy: kCLLocationAccuracyBest,
                verticalAccuracy: -1,
                timestamp: Date()
            )

            parent.onWaypointsWillChange?(parent.waypoints)
            parent.waypoints.append(location)
        }

        @objc func handlePointDrag(_ gesture: UIPanGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)

            switch gesture.state {
            case .began:
                guard gesture.numberOfTouches == 1 else {
                    draggedWaypointIndex = nil
                    mapView.isScrollEnabled = true
                    return
                }
                draggedWaypointIndex = nearestWaypointIndex(to: point, in: mapView)
                mapView.isScrollEnabled = draggedWaypointIndex == nil
            case .changed:
                guard gesture.numberOfTouches == 1, let draggedWaypointIndex else {
                    self.draggedWaypointIndex = nil
                    mapView.isScrollEnabled = true
                    return
                }
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                annotation(for: draggedWaypointIndex, in: mapView)?.coordinate = coordinate
            case .ended, .cancelled, .failed:
                defer {
                    draggedWaypointIndex = nil
                    mapView.isScrollEnabled = true
                }
                guard let draggedWaypointIndex,
                      parent.waypoints.indices.contains(draggedWaypointIndex) else {
                    return
                }

                parent.onWaypointsWillChange?(parent.waypoints)
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                parent.waypoints[draggedWaypointIndex] = CLLocation(
                    coordinate: coordinate,
                    altitude: 0,
                    horizontalAccuracy: kCLLocationAccuracyBest,
                    verticalAccuracy: -1,
                    timestamp: Date()
                )
                waypointSignature = ""
                completedRouteRequestSignature = ""
            default:
                break
            }
        }

        func syncRoute(on mapView: MKMapView) {
            self.mapView = mapView
            positionInitialRegion(on: mapView, userCoordinate: mapView.userLocation.location?.coordinate)

            let signature = mapSignature(for: parent.waypoints)
            guard signature != waypointSignature else {
                renderRouteIfNeeded(on: mapView)
                return
            }

            waypointSignature = signature
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

            let coordinates = parent.waypoints.map(\.coordinate)
            let annotations = coordinates.enumerated().map { index, coordinate in
                RouteWaypointAnnotation(
                    coordinate: coordinate,
                    index: index,
                    title: title(for: index, count: coordinates.count)
                )
            }
            mapView.addAnnotations(annotations)

            guard coordinates.count > 1 else {
                directionsTask?.cancel()
                retryTask?.cancel()
                activeRouteRequestSignature = ""
                completedRouteRequestSignature = ""
                parent.resolvedRoute = parent.waypoints
                renderRouteIfNeeded(on: mapView)
                return
            }

            calculateRoadRoute(for: parent.waypoints, on: mapView)
        }

        private func calculateRoadRoute(for waypoints: [CLLocation], on mapView: MKMapView) {
            let requestSignature = mapSignature(for: waypoints)
            guard requestSignature != activeRouteRequestSignature,
                  requestSignature != completedRouteRequestSignature else {
                return
            }

            directionsTask?.cancel()
            retryTask?.cancel()
            activeRouteRequestSignature = requestSignature
            directionsTask = Task { [weak self, weak mapView] in
                guard let self else { return }
                var routedLocations: [CLLocation] = []
                defer {
                    Task { @MainActor [weak self] in
                        guard self?.activeRouteRequestSignature == requestSignature else { return }
                        self?.activeRouteRequestSignature = ""
                    }
                }

                for pair in zip(waypoints, waypoints.dropFirst()) {
                    guard !Task.isCancelled else { return }
                    do {
                        let segment = try await self.cachedRouteSegment(from: pair.0.coordinate, to: pair.1.coordinate)
                        guard segment.count > 2 else {
                            self.scheduleRouteRetry(for: waypoints, signature: requestSignature, on: mapView, after: 2)
                            return
                        }
                        if routedLocations.isEmpty {
                            routedLocations.append(contentsOf: segment)
                        } else {
                            routedLocations.append(contentsOf: segment.dropFirst())
                        }
                    } catch {
                        self.scheduleRouteRetry(
                            for: waypoints,
                            signature: requestSignature,
                            on: mapView,
                            after: self.retryDelay(for: error)
                        )
                        return
                    }
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.activeRouteRequestSignature == requestSignature else { return }
                    self.completedRouteRequestSignature = requestSignature
                    self.routeRetryCounts[requestSignature] = nil
                    self.parent.resolvedRoute = routedLocations
                    if let mapView {
                        self.renderRouteIfNeeded(on: mapView)
                    }
                }
            }
        }

        @MainActor
        private func scheduleRouteRetry(
            for waypoints: [CLLocation],
            signature: String,
            on mapView: MKMapView?,
            after delay: TimeInterval
        ) {
            guard activeRouteRequestSignature == signature,
                  mapSignature(for: parent.waypoints) == signature,
                  let mapView else {
                return
            }

            let retryCount = routeRetryCounts[signature, default: 0]
            guard retryCount < 4 else {
                activeRouteRequestSignature = ""
                return
            }

            routeRetryCounts[signature] = retryCount + 1
            activeRouteRequestSignature = ""
            retryTask?.cancel()
            retryTask = Task { [weak self, weak mapView] in
                let nanoseconds = UInt64(max(delay, 0.5) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled, let self, let mapView else { return }

                await MainActor.run {
                    guard self.mapSignature(for: self.parent.waypoints) == signature else { return }
                    self.calculateRoadRoute(for: waypoints, on: mapView)
                }
            }
        }

        private func retryDelay(for error: Error) -> TimeInterval {
            let nsError = error as NSError
            if let reset = nsError.userInfo["timeUntilReset"] as? TimeInterval {
                return reset + 0.75
            }
            if let reset = nsError.userInfo["timeUntilReset"] as? Int {
                return TimeInterval(reset) + 0.75
            }
            return 2
        }

        private func cachedRouteSegment(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [CLLocation] {
            let key = segmentCacheKey(from: source, to: destination)
            if let segment = segmentCache[key] {
                return segment
            }

            let segment = try await routeSegment(from: source, to: destination)
            await MainActor.run {
                segmentCache[key] = segment
            }
            return segment
        }

        private func routeSegment(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [CLLocation] {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .walking
            request.requestsAlternateRoutes = false

            guard let route = try await MKDirections(request: request).calculate().routes.first else {
                return []
            }

            return route.polyline.locations
        }

        private func renderRouteIfNeeded(on mapView: MKMapView) {
            let route = parent.resolvedRoute
            let signature = mapSignature(for: route)
            guard renderedRouteSignature != signature else { return }

            renderedRouteSignature = signature
            mapView.removeOverlays(mapView.overlays)
            guard route.count > 1 else { return }

            let coordinates = route.map(\.coordinate)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }

        private func positionInitialRegion(on mapView: MKMapView, userCoordinate: CLLocationCoordinate2D?) {
            if hasPositionedInitialRegion {
                guard !hasPositionedOnUserLocation, parent.waypoints.isEmpty, userCoordinate != nil else { return }
            }
            hasPositionedInitialRegion = true
            hasPositionedOnUserLocation = userCoordinate != nil && parent.waypoints.isEmpty

            let center = parent.waypoints.first?.coordinate
                ?? userCoordinate
                ?? locationManager.location?.coordinate
                ?? CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241)
            mapView.setRegion(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                ),
                animated: false
            )
        }

        private func mapSignature(for route: [CLLocation]) -> String {
            guard !route.isEmpty else {
                return "empty:\(route.count)"
            }

            return route
                .map { coordinateKey($0.coordinate) }
                .joined(separator: "|")
        }

        private func segmentCacheKey(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> String {
            "\(coordinateKey(source))>\(coordinateKey(destination))"
        }

        private func coordinateKey(_ coordinate: CLLocationCoordinate2D) -> String {
            "\(coordinate.latitude.rounded(toPlaces: 5)),\(coordinate.longitude.rounded(toPlaces: 5))"
        }

        private func title(for index: Int, count: Int) -> String {
            if index == 0 { return "Start" }
            if index == count - 1 { return "Finish" }
            return "Point \(index + 1)"
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard let mapView else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            default:
                positionInitialRegion(on: mapView, userCoordinate: nil)
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let coordinate = locations.last?.coordinate, let mapView else { return }
            positionInitialRegion(on: mapView, userCoordinate: coordinate)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            guard let mapView else { return }
            positionInitialRegion(on: mapView, userCoordinate: nil)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.82)
            renderer.lineWidth = 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "RoutePlannerPoint"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.isDraggable = false
            view.displayPriority = .required

            switch annotation.title ?? nil {
            case "Start":
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "figure.run")
            case "Finish":
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.checkered")
            default:
                view.markerTintColor = .systemBlue
                view.glyphText = nil
                view.glyphImage = nil
            }

            return view
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
                  let mapView = gestureRecognizer.view as? MKMapView else {
                return true
            }

            guard panGesture.numberOfTouches <= 1,
                  nearestWaypointIndex(to: panGesture.location(in: mapView), in: mapView) != nil else {
                return false
            }

            let velocity = panGesture.velocity(in: mapView)
            let dominantVelocity = max(abs(velocity.x), abs(velocity.y))
            return dominantVelocity < 650
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer else { return true }
            return draggedWaypointIndex == nil
        }

        private func nearestWaypointIndex(to point: CGPoint, in mapView: MKMapView) -> Int? {
            let hitRadius: CGFloat = 56
            return parent.waypoints.enumerated().compactMap { index, location -> (Int, CGFloat)? in
                let waypointPoint = mapView.convert(location.coordinate, toPointTo: mapView)
                let distance = hypot(point.x - waypointPoint.x, point.y - waypointPoint.y)
                guard distance <= hitRadius else { return nil }
                return (index, distance)
            }
            .min { $0.1 < $1.1 }?
            .0
        }

        private func annotation(for index: Int, in mapView: MKMapView) -> RouteWaypointAnnotation? {
            mapView.annotations.compactMap { $0 as? RouteWaypointAnnotation }.first { $0.index == index }
        }
    }
}

private final class RouteWaypointAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let index: Int
    let title: String?

    init(coordinate: CLLocationCoordinate2D, index: Int, title: String?) {
        self.coordinate = coordinate
        self.index = index
        self.title = title
    }
}

struct RoutePlannerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftWaypoints: [CLLocation]
    @State private var resolvedRoute: [CLLocation]
    @State private var waypointHistory: [[CLLocation]] = []
    @State private var displayMode: RouteMapDisplayMode = .standard

    let tintColor: Color
    let onSave: ([CLLocation], [CLLocation]) -> Void

    init(
        route: [CLLocation],
        waypoints: [CLLocation]? = nil,
        tintColor: Color,
        onSave: @escaping ([CLLocation], [CLLocation]) -> Void
    ) {
        _draftWaypoints = State(initialValue: waypoints ?? route)
        _resolvedRoute = State(initialValue: route)
        self.tintColor = tintColor
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                plannerToolbar

                RoutePlannerMapView(
                    waypoints: $draftWaypoints,
                    resolvedRoute: $resolvedRoute,
                    displayMode: displayMode,
                    onWaypointsWillChange: storeUndoState
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Plan Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Route") {
                        onSave(routeToSave, draftWaypoints)
                        dismiss()
                    }
                    .disabled(!canUseRoute)
                }
            }
        }
    }

    private var plannerToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Map Style", selection: $displayMode) {
                ForEach(RouteMapDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Label(routeSummaryText, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    undoLastPoint()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(!canUndo)
                .accessibilityLabel("Undo last route point")

                Button(role: .destructive) {
                    storeUndoState(draftWaypoints)
                    draftWaypoints.removeAll()
                    resolvedRoute.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(draftWaypoints.isEmpty)
                .accessibilityLabel("Clear route")
            }

            Text("Tap the map to add points. Press and drag a marker to move it. Undo reverses your last edit, and Clear removes the full route. Routes follow available walking roads and paths.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var routeToSave: [CLLocation] {
        resolvedRoute
    }

    private var canUseRoute: Bool {
        routeIsReady
    }

    private var routeSummaryText: String {
        guard draftWaypoints.count > 1 else {
            return "\(draftWaypoints.count) point\(draftWaypoints.count == 1 ? "" : "s")"
        }
        guard resolvedRoute.count > 1 else {
            return "Calculating road route..."
        }
        guard routeIsReady else {
            return "Updating road route..."
        }

        let distance = routeToSave.routeDistanceKilometers
        return "\(String(format: "%.2f", distance)) km · \(draftWaypoints.count) points"
    }

    private var routeIsReady: Bool {
        guard draftWaypoints.count > 1,
              resolvedRoute.count > 1,
              let firstWaypoint = draftWaypoints.first,
              let lastWaypoint = draftWaypoints.last,
              let firstRoutePoint = resolvedRoute.first,
              let lastRoutePoint = resolvedRoute.last else {
            return false
        }

        return firstRoutePoint.distance(from: firstWaypoint) < 50
            && lastRoutePoint.distance(from: lastWaypoint) < 50
    }

    private func undoLastPoint() {
        if let previousWaypoints = waypointHistory.popLast() {
            draftWaypoints = previousWaypoints
            resolvedRoute.removeAll()
        } else if !draftWaypoints.isEmpty {
            draftWaypoints.removeLast()
            resolvedRoute.removeAll()
        }
    }

    private var canUndo: Bool {
        !waypointHistory.isEmpty || !draftWaypoints.isEmpty
    }

    private func storeUndoState(_ waypoints: [CLLocation]) {
        waypointHistory.append(waypoints)
    }
}

extension Array where Element == CLLocation {
    var routeDistanceKilometers: Double {
        guard count > 1 else { return 0 }

        return zip(self, dropFirst()).reduce(0) { partialResult, pair in
            partialResult + pair.0.distance(from: pair.1)
        } / 1000
    }
}

private extension MKPolyline {
    var locations: [CLLocation] {
        var coordinates = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

#Preview {
    RoutePlannerSheetView(route: [], tintColor: .blue) { _, _ in }
}
