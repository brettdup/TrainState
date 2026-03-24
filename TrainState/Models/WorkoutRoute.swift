import Foundation
import SwiftData
import CoreLocation

// New model for route data
@Model
final class WorkoutRoute {
    var id: UUID = UUID()
    var routeData: Data? // Encoded [CLLocation]
    @Transient private var cachedDecodedRoute: [CLLocation]?
    @Transient private var cachedRouteFingerprint: RouteDataFingerprint?
    
    // SwiftData relationship - CloudKit compatible
    var workout: Workout?

    init(routeData: Data? = nil) {
        self.id = UUID()
        self.routeData = routeData
    }

    // Helper to get/set route as [CLLocation]
    var decodedRoute: [CLLocation]? {
        get {
            guard let data = routeData else {
                cachedDecodedRoute = nil
                cachedRouteFingerprint = nil
                return nil
            }

            let fingerprint = RouteDataFingerprint(data: data)
            if cachedRouteFingerprint == fingerprint {
                return cachedDecodedRoute
            }

            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                let locations = try unarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey) as? [CLLocation]
                unarchiver.finishDecoding()
                guard let locations = locations, locations.count <= 2000 else {
                    cachedDecodedRoute = nil
                    cachedRouteFingerprint = fingerprint
                    return nil
                }
                cachedDecodedRoute = locations
                cachedRouteFingerprint = fingerprint
                return locations
            } catch {
                cachedDecodedRoute = nil
                cachedRouteFingerprint = fingerprint
                return nil
            }
        }
        set {
            guard let locations = newValue else {
                routeData = nil
                cachedDecodedRoute = nil
                cachedRouteFingerprint = nil
                return
            }
            // Save all points, no limit
            let limitedLocations = locations
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: limitedLocations, requiringSecureCoding: false)
                routeData = data
                cachedDecodedRoute = limitedLocations
                cachedRouteFingerprint = RouteDataFingerprint(data: data)
            } catch {
                routeData = nil
                cachedDecodedRoute = nil
                cachedRouteFingerprint = nil
            }
        }
    }
    
    // Helper method to get route summary for display
    var routeSummary: RouteSummary? {
        guard let locations = decodedRoute, !locations.isEmpty else { return nil }
        
        let totalDistance = calculateTotalDistance(from: locations)
        let duration = locations.last?.timestamp.timeIntervalSince(locations.first?.timestamp ?? Date()) ?? 0
        
        return RouteSummary(
            pointCount: locations.count,
            totalDistance: totalDistance,
            duration: duration,
            startLocation: locations.first,
            endLocation: locations.last
        )
    }
    
    private func calculateTotalDistance(from locations: [CLLocation]) -> CLLocationDistance {
        var totalDistance: CLLocationDistance = 0
        
        for i in 1..<locations.count {
            let distance = locations[i].distance(from: locations[i-1])
            totalDistance += distance
        }
        
        return totalDistance
    }
}

private struct RouteDataFingerprint: Equatable {
    let count: Int
    let prefixHash: Int
    let suffixHash: Int

    init(data: Data) {
        count = data.count
        prefixHash = data.prefix(64).hashValue
        suffixHash = data.suffix(64).hashValue
    }
}

// Helper struct for route summary
struct RouteSummary {
    let pointCount: Int
    let totalDistance: CLLocationDistance
    let duration: TimeInterval
    let startLocation: CLLocation?
    let endLocation: CLLocation?
} 
