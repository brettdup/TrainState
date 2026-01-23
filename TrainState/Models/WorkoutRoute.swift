import Foundation
import SwiftData
import CoreLocation

// New model for route data
@Model
final class WorkoutRoute {
    var id: UUID = UUID()
    var routeData: Data? // Encoded [CLLocation]
    
    // SwiftData relationship - CloudKit compatible
    var workout: Workout?

    init(routeData: Data? = nil) {
        self.id = UUID()
        self.routeData = routeData
    }

    // Helper to get/set route as [CLLocation]
    var decodedRoute: [CLLocation]? {
        get {
            print("[WorkoutRoute] Decoding route data: data exists? \(routeData != nil)")
            if let data = routeData {
                print("[WorkoutRoute] Data size: \(data.count) bytes")
            }
            guard let data = routeData else { return nil }
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                let locations = try unarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey) as? [CLLocation]
                unarchiver.finishDecoding()
                print("[WorkoutRoute] Decoded locations count: \(locations?.count ?? 0)")
                if let locations = locations, !locations.isEmpty {
                    print("[WorkoutRoute] First location: \(locations.first!)")
                    print("[WorkoutRoute] Last location: \(locations.last!)")
                    print("[WorkoutRoute] Sample locations:")
                    for i in stride(from: 0, to: locations.count, by: max(1, locations.count/10)) {
                        print("  [\(i)] \(locations[i])")
                    }
                }
                guard let locations = locations, locations.count <= 2000 else {
                    print("[WorkoutRoute] Invalid location data: too many points or nil data")
                    return nil
                }
                return locations
            } catch {
                print("[WorkoutRoute] Error decoding route data: \(error.localizedDescription)")
                return nil
            }
        }
        set {
            if let locations = newValue {
                print("[WorkoutRoute] Encoding locations count: \(locations.count)")
            } else {
                print("[WorkoutRoute] Setting decodedRoute to nil")
            }
            guard let locations = newValue else {
                routeData = nil
                return
            }
            // Save all points, no limit
            let limitedLocations = locations
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: limitedLocations, requiringSecureCoding: false)
                print("[WorkoutRoute] Encoded data size: \(data.count) bytes")
                routeData = data
            } catch {
                print("[WorkoutRoute] Error encoding route data: \(error.localizedDescription)")
                routeData = nil
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

// Helper struct for route summary
struct RouteSummary {
    let pointCount: Int
    let totalDistance: CLLocationDistance
    let duration: TimeInterval
    let startLocation: CLLocation?
    let endLocation: CLLocation?
} 