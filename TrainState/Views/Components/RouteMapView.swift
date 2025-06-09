import SwiftUI
import MapKit
import CoreLocation

struct RouteMapView: UIViewRepresentable {
    let route: [CLLocation]

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
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard route.count > 1 else {
            // Center on a default location if no route
            let region = MKCoordinateRegion(
                center: route.first?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
            return
        }
        // Polyline
        let coords = route.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        mapView.addOverlay(polyline)
        // Start/End annotations
        let start = MKPointAnnotation()
        start.coordinate = coords.first!
        start.title = "Start"
        let end = MKPointAnnotation()
        end.coordinate = coords.last!
        end.title = "End"
        mapView.addAnnotations([start, end])
        // Zoom to fit
        var rect = polyline.boundingMapRect
        let padding: Double = 0.02
        rect = rect.insetBy(dx: -rect.size.width * padding, dy: -rect.size.height * padding)
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32), animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
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
            let identifier = "RouteAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }
            if annotation.title == "Start" {
                (view as? MKMarkerAnnotationView)?.markerTintColor = .systemGreen
            } else if annotation.title == "End" {
                (view as? MKMarkerAnnotationView)?.markerTintColor = .systemRed
            }
            return view
        }
    }
}

struct IdentifiableLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
} 