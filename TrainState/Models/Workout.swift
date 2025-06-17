import Foundation
import SwiftData
import CoreLocation

@Model
final class Workout {
    var id: UUID = UUID()
    var healthKitUUID: UUID?
    var type: WorkoutType = WorkoutType.other
    var startDate: Date = Date()
    var duration: TimeInterval = 0
    var calories: Double?
    var distance: Double?
    var notes: String?
    
    // SwiftData relationships - CloudKit compatible
    @Relationship(inverse: \WorkoutCategory.workouts)
    var categories: [WorkoutCategory]? = []
    @Relationship(inverse: \WorkoutSubcategory.workouts)
    var subcategories: [WorkoutSubcategory]? = []
    var route: WorkoutRoute?
    
    init(
        type: WorkoutType = WorkoutType.other,
        startDate: Date = Date(),
        duration: TimeInterval = 0,
        calories: Double? = nil,
        distance: Double? = nil,
        notes: String? = nil,
        categories: [WorkoutCategory]? = nil,
        subcategories: [WorkoutSubcategory]? = nil,
        healthKitUUID: UUID? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.startDate = startDate
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.notes = notes
        self.categories = categories
        self.subcategories = subcategories
        self.healthKitUUID = healthKitUUID
    }
    
    // Helper methods to maintain relationship integrity
    func addCategory(_ category: WorkoutCategory) {
        if categories == nil { self.categories = [] }
        if !(categories?.contains(where: { $0.id == category.id }) ?? false) {
            categories?.append(category)
            category.workouts?.append(self)
        }
    }
    
    func removeCategory(_ category: WorkoutCategory) {
        categories?.removeAll { $0.id == category.id }
        category.workouts?.removeAll { $0.id == self.id }
    }
    
    func addSubcategory(_ subcategory: WorkoutSubcategory) {
        if subcategories == nil { self.subcategories = [] }
        if !(subcategories?.contains(where: { $0.id == subcategory.id }) ?? false) {
            subcategories?.append(subcategory)
            subcategory.workouts?.append(self)
        }
    }
    
    func removeSubcategory(_ subcategory: WorkoutSubcategory) {
        subcategories?.removeAll { $0.id == subcategory.id }
        subcategory.workouts?.removeAll { $0.id == self.id }
    }
}

// Make WorkoutType codable for export/import functionality
enum WorkoutType: String, Codable, CaseIterable {
    case strength = "Strength Training"
    case cardio = "Cardio"
    case yoga = "Yoga"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case other = "Other"
}

// MARK: - Codable Extensions for Export/Import
// These are separate from the @Model classes to avoid SwiftData conflicts

struct WorkoutExport: Codable {
    let id: UUID
    let healthKitUUID: UUID?
    let type: WorkoutType
    let startDate: Date
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let notes: String?
    let categoryIds: [UUID]?
    let subcategoryIds: [UUID]?
    
    init(from workout: Workout) {
        self.id = workout.id
        self.healthKitUUID = workout.healthKitUUID
        self.type = workout.type
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.calories = workout.calories
        self.distance = workout.distance
        self.notes = workout.notes
        self.categoryIds = workout.categories?.map { $0.id }
        self.subcategoryIds = workout.subcategories?.map { $0.id }
    }
}

struct WorkoutCategoryExport: Codable {
    let id: UUID
    let name: String
    let color: String
    let workoutType: WorkoutType?
    
    init(from category: WorkoutCategory) {
        self.id = category.id
        self.name = category.name
        self.color = category.color
        self.workoutType = category.workoutType
    }
}

struct WorkoutSubcategoryExport: Codable {
    let id: UUID
    let name: String
    
    init(from subcategory: WorkoutSubcategory) {
        self.id = subcategory.id
        self.name = subcategory.name
    }
} 
