import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var isOnboarded: Bool
    var preferredWorkoutTypes: [WorkoutType]
    var notificationEnabled: Bool
    var notificationTime: Date?
    var darkModeEnabled: Bool
    var measurementSystem: MeasurementSystem
    
    init(
        isOnboarded: Bool = false,
        preferredWorkoutTypes: [WorkoutType] = [],
        notificationEnabled: Bool = false,
        notificationTime: Date? = nil,
        darkModeEnabled: Bool = false,
        measurementSystem: MeasurementSystem = .metric
    ) {
        self.id = UUID()
        self.isOnboarded = isOnboarded
        self.preferredWorkoutTypes = preferredWorkoutTypes
        self.notificationEnabled = notificationEnabled
        self.notificationTime = notificationTime
        self.darkModeEnabled = darkModeEnabled
        self.measurementSystem = measurementSystem
    }
}

enum MeasurementSystem: String, Codable {
    case metric
    case imperial
} 