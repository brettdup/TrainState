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
            guard let data = routeData else { return nil }
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                let locations = try unarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey) as? [CLLocation]
                unarchiver.finishDecoding()
                return locations
            } catch {
                print("[WorkoutRoute] Error decoding route data: \(error.localizedDescription)")
                return nil
            }
        }
        set {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: newValue ?? [], requiringSecureCoding: false)
                routeData = data
            } catch {
                print("[WorkoutRoute] Error encoding route data: \(error.localizedDescription)")
                routeData = nil
            }
        }
    }
} 