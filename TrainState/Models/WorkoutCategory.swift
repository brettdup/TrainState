import Foundation
import SwiftData
import HealthKit

@Model
final class WorkoutCategory {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#FF0000" // Store as hex string
    var workoutType: WorkoutType?
    var appleWorkoutActivityTypeRaw: Int?

    var appleWorkoutActivityType: HKWorkoutActivityType? {
        get {
            guard let appleWorkoutActivityTypeRaw else { return nil }
            return HKWorkoutActivityType(rawValue: UInt(appleWorkoutActivityTypeRaw))
        }
        set {
            appleWorkoutActivityTypeRaw = newValue.map { Int($0.rawValue) }
        }
    }

    var resolvedWorkoutType: WorkoutType? {
        appleWorkoutActivityType?.mappedWorkoutType ?? workoutType
    }
    
    // SwiftData relationships - CloudKit compatible
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSubcategory.category)
    var subcategories: [WorkoutSubcategory]? = []
    var workouts: [Workout]? = []
    
    init(
        name: String = "",
        color: String = "#FF0000",
        workoutType: WorkoutType? = nil,
        appleWorkoutActivityType: HKWorkoutActivityType? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.workoutType = workoutType ?? appleWorkoutActivityType?.mappedWorkoutType
        self.appleWorkoutActivityTypeRaw = appleWorkoutActivityType.map { Int($0.rawValue) }
        self.subcategories = []
    }
    
    // Helper methods to maintain relationship integrity
    func addSubcategory(_ subcategory: WorkoutSubcategory) {
        if subcategories == nil { self.subcategories = [] }
        if !(subcategories?.contains(where: { $0.id == subcategory.id }) ?? false) {
            subcategories?.append(subcategory)
            subcategory.category = self
        }
    }
    
    func removeSubcategory(_ subcategory: WorkoutSubcategory) {
        subcategories?.removeAll { $0.id == subcategory.id }
        if subcategory.category?.id == self.id {
            subcategory.category = nil
        }
    }
    

    
    var activityDisplayName: String {
        appleWorkoutActivityType?.displayName ?? resolvedWorkoutType?.rawValue ?? "Unspecified"
    }

    func matches(
        appleWorkoutActivityType: HKWorkoutActivityType?,
        fallbackWorkoutType: WorkoutType
    ) -> Bool {
        if let categoryActivity = self.appleWorkoutActivityType {
            if let appleWorkoutActivityType, categoryActivity == appleWorkoutActivityType {
                return true
            }
            return categoryActivity.mappedWorkoutType == fallbackWorkoutType
        }

        return workoutType == fallbackWorkoutType
    }

    static func categoriesForType(_ type: WorkoutType, from allCategories: [WorkoutCategory]) -> [WorkoutCategory] {
        return allCategories.filter { $0.resolvedWorkoutType == type }
    }

    static func categoriesForAppleWorkout(
        activityType: HKWorkoutActivityType?,
        fallbackWorkoutType: WorkoutType,
        from allCategories: [WorkoutCategory]
    ) -> [WorkoutCategory] {
        allCategories.filter {
            $0.matches(
                appleWorkoutActivityType: activityType,
                fallbackWorkoutType: fallbackWorkoutType
            )
        }
    }
} 
