import Foundation
import SwiftData
import CoreLocation

// New model for route data
@Model
final class WorkoutRoute {
    var id: UUID = UUID()
    var name: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var routeData: Data? // Encoded [CLLocation]
    var waypointData: Data? // Encoded tapped route control points
    @Transient private var cachedDecodedRoute: [CLLocation]?
    @Transient private var cachedRouteFingerprint: RouteDataFingerprint?
    @Transient private var cachedDecodedWaypoints: [CLLocation]?
    @Transient private var cachedWaypointFingerprint: RouteDataFingerprint?
    
    // SwiftData relationship - CloudKit compatible
    var workout: Workout?

    init(name: String? = nil, routeData: Data? = nil, waypointData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.routeData = routeData
        self.waypointData = waypointData
    }

    // Helper to get/set route as [CLLocation]
    var decodedRoute: [CLLocation]? {
        get {
            decodeLocations(
                from: routeData,
                cachedLocations: &cachedDecodedRoute,
                cachedFingerprint: &cachedRouteFingerprint
            )
        }
        set {
            encodeLocations(
                newValue,
                data: &routeData,
                cachedLocations: &cachedDecodedRoute,
                cachedFingerprint: &cachedRouteFingerprint
            )
        }
    }

    var decodedWaypoints: [CLLocation]? {
        get {
            decodeLocations(
                from: waypointData,
                cachedLocations: &cachedDecodedWaypoints,
                cachedFingerprint: &cachedWaypointFingerprint
            )
        }
        set {
            encodeLocations(
                newValue,
                data: &waypointData,
                cachedLocations: &cachedDecodedWaypoints,
                cachedFingerprint: &cachedWaypointFingerprint
            )
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

    private func decodeLocations(
        from data: Data?,
        cachedLocations: inout [CLLocation]?,
        cachedFingerprint: inout RouteDataFingerprint?
    ) -> [CLLocation]? {
        guard let data else {
            cachedLocations = nil
            cachedFingerprint = nil
            return nil
        }

        let fingerprint = RouteDataFingerprint(data: data)
        if cachedFingerprint == fingerprint {
            return cachedLocations
        }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            let locations = try unarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey) as? [CLLocation]
            unarchiver.finishDecoding()
            guard let locations = locations, locations.count <= 3000 else {
                cachedLocations = nil
                cachedFingerprint = fingerprint
                return nil
            }
            cachedLocations = locations
            cachedFingerprint = fingerprint
            return locations
        } catch {
            cachedLocations = nil
            cachedFingerprint = fingerprint
            return nil
        }
    }

    private func encodeLocations(
        _ locations: [CLLocation]?,
        data: inout Data?,
        cachedLocations: inout [CLLocation]?,
        cachedFingerprint: inout RouteDataFingerprint?
    ) {
        guard let locations else {
            data = nil
            cachedLocations = nil
            cachedFingerprint = nil
            return
        }

        do {
            let encodedData = try NSKeyedArchiver.archivedData(withRootObject: locations, requiringSecureCoding: false)
            data = encodedData
            updatedAt = Date()
            cachedLocations = locations
            cachedFingerprint = RouteDataFingerprint(data: encodedData)
        } catch {
            data = nil
            cachedLocations = nil
            cachedFingerprint = nil
        }
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
