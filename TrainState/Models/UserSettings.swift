import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID = UUID()
    var isOnboarded: Bool = false
    var preferredWorkoutTypes: [WorkoutType] = []
    var notificationEnabled: Bool = false
    var notificationTime: Date?
    var darkModeEnabled: Bool = false
    var measurementSystem: MeasurementSystem = MeasurementSystem.metric
    var hasInitializedDefaultCategories: Bool = false
    
    init(
        id: UUID = UUID(),
        isOnboarded: Bool = false,
        preferredWorkoutTypes: [WorkoutType] = [],
        notificationEnabled: Bool = false,
        notificationTime: Date? = nil,
        darkModeEnabled: Bool = false,
        measurementSystem: MeasurementSystem = MeasurementSystem.metric
    ) {
        self.id = id
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
