import SwiftUI
import MapKit
import CoreLocation

private final class PlaybackAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "PlaybackAnnotation"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        centerOffset = CGPoint(x: 0, y: -9)
        canShowCallout = false

        layer.cornerRadius = 9
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
        backgroundColor = .systemBlue
        alpha = 0.96
        displayPriority = .required
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PlaybackAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    init(coordinate: CLLocationCoordinate2D, title: String? = nil) {
        self.coordinate = coordinate
        self.title = title
    }
}

enum RouteMapDisplayMode: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case satellite = "Satellite"

    var id: String { rawValue }

    var mapType: MKMapType {
        switch self {
        case .standard:
            return .standard
        case .satellite:
            return .satellite
        }
    }
}

struct RouteMapView: UIViewRepresentable {
    let route: [CLLocation]
    var displayMode: RouteMapDisplayMode = .standard
    var isPlaybackActive: Bool = false
    var playbackTrigger: Int = 0
    var onPlaybackFinished: (() -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.mapType = displayMode.mapType
        context.coordinator.syncMap(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView
        private var routeSignature = ""
        private var lastPlaybackTrigger = 0
        private weak var mapView: MKMapView?
        private var playbackAnnotation: PlaybackAnnotation?
        private var playbackTimer: Timer?
        private var playbackIndex = 0

        init(parent: RouteMapView) {
            self.parent = parent
        }

        deinit {
            playbackTimer?.invalidate()
        }

        func syncMap(_ mapView: MKMapView) {
            self.mapView = mapView
            let signature = mapSignature(for: parent.route)

            if signature != routeSignature {
                routeSignature = signature
                configureMap(mapView)
                if parent.isPlaybackActive {
                    startPlayback()
                } else {
                    pausePlayback(resetMarker: true, resetProgress: true)
                }
            } else if parent.isPlaybackActive {
                if parent.playbackTrigger != lastPlaybackTrigger {
                    startPlayback()
                } else if playbackTimer == nil {
                    startPlayback()
                }
            } else {
                pausePlayback(resetMarker: false, resetProgress: false)
            }
        }

        private func configureMap(_ mapView: MKMapView) {
            pausePlayback(resetMarker: false, resetProgress: true)
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            playbackAnnotation = nil
            playbackIndex = 0

            guard parent.route.count > 1 else {
                let region = MKCoordinateRegion(
                    center: parent.route.first?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(region, animated: true)
                return
            }

            let coords = parent.route.map(\.coordinate)
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            mapView.addOverlay(polyline)

            let start = MKPointAnnotation()
            start.coordinate = coords.first!
            start.title = "Start"

            let end = MKPointAnnotation()
            end.coordinate = coords.last!
            end.title = "End"

            mapView.addAnnotations([start, end])

            var rect = polyline.boundingMapRect
            let padding: Double = 0.02
            rect = rect.insetBy(dx: -rect.size.width * padding, dy: -rect.size.height * padding)
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32), animated: true)
        }

        private func mapSignature(for route: [CLLocation]) -> String {
            guard let first = route.first?.coordinate, let last = route.last?.coordinate else {
                return "empty:\(route.count)"
            }
            return "\(route.count):\(first.latitude):\(first.longitude):\(last.latitude):\(last.longitude)"
        }

        private func startPlayback() {
            guard let mapView, parent.route.count > 1 else { return }

            pausePlayback(resetMarker: false, resetProgress: false)
            lastPlaybackTrigger = parent.playbackTrigger

            let startingIndex = min(playbackIndex, max(parent.route.count - 1, 0))
            let coordinate = parent.route[startingIndex].coordinate
            let annotation = playbackAnnotation ?? PlaybackAnnotation(coordinate: coordinate, title: "Playback")
            annotation.coordinate = coordinate
            playbackAnnotation = annotation

            if mapView.view(for: annotation) == nil {
                mapView.removeAnnotation(annotation)
                mapView.addAnnotation(annotation)
            }

            playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackInterval(for: parent.route.count), repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.advancePlayback()
            }

            if let playbackTimer {
                RunLoop.main.add(playbackTimer, forMode: .common)
            }
        }

        private func advancePlayback() {
            guard let annotation = playbackAnnotation else { return }

            let nextIndex = playbackIndex + 1
            guard nextIndex < parent.route.count else {
                pausePlayback(resetMarker: true, resetProgress: true)
                DispatchQueue.main.async { [onPlaybackFinished = parent.onPlaybackFinished] in
                    onPlaybackFinished?()
                }
                return
            }

            playbackIndex = nextIndex
            let coordinate = parent.route[nextIndex].coordinate

            annotation.coordinate = coordinate
        }

        private func pausePlayback(resetMarker: Bool, resetProgress: Bool) {
            playbackTimer?.invalidate()
            playbackTimer = nil

            if resetProgress {
                playbackIndex = 0
            }

            guard resetMarker, let mapView, let annotation = playbackAnnotation else { return }
            mapView.removeAnnotation(annotation)
            playbackAnnotation = nil
        }

        private func playbackInterval(for pointCount: Int) -> TimeInterval {
            let duration = min(max(Double(pointCount) * 0.08, 8.0), 24.0)
            return duration / Double(pointCount)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation.title == "Playback" {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: PlaybackAnnotationView.reuseIdentifier
                ) as? PlaybackAnnotationView ?? PlaybackAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: PlaybackAnnotationView.reuseIdentifier
                )
                view.annotation = annotation
                return view
            }

            let identifier = "RouteAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }

            guard let markerView = view as? MKMarkerAnnotationView else {
                return view
            }

            markerView.canShowCallout = false
            markerView.displayPriority = .required

            if annotation.title == "Start" {
                markerView.markerTintColor = .systemGreen
                markerView.glyphImage = nil
            } else if annotation.title == "End" {
                markerView.markerTintColor = .systemRed
                markerView.glyphImage = nil
            }
            return view
        }
    }
}

struct RouteMapSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let route: [CLLocation]
    @State private var displayMode: RouteMapDisplayMode = .standard
    @State private var isPlaybackActive = false
    @State private var playbackTrigger = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Picker("Map Style", selection: $displayMode) {
                        ForEach(RouteMapDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        if isPlaybackActive {
                            isPlaybackActive = false
                        } else {
                            playbackTrigger += 1
                            isPlaybackActive = true
                        }
                    } label: {
                        Image(systemName: isPlaybackActive ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 42, height: 36)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                RouteMapView(
                    route: route,
                    displayMode: displayMode,
                    isPlaybackActive: isPlaybackActive,
                    playbackTrigger: playbackTrigger,
                    onPlaybackFinished: {
                        isPlaybackActive = false
                        playbackTrigger = 0
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Workout Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        resetState()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            resetState()
        }
    }

    private func resetState() {
        displayMode = .standard
        isPlaybackActive = false
        playbackTrigger = 0
    }
}

struct IdentifiableLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
}

#Preview {
    let route = [
        CLLocation(latitude: 37.7749, longitude: -122.4194),
        CLLocation(latitude: 37.7760, longitude: -122.4172),
        CLLocation(latitude: 37.7772, longitude: -122.4148),
        CLLocation(latitude: 37.7785, longitude: -122.4127)
    ]

    return RouteMapView(route: route)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
}
