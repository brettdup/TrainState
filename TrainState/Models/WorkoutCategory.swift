import Foundation
import SwiftData

@Model
final class WorkoutCategory {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#FF0000" // Store as hex string
    var workoutType: WorkoutType?
    
    // SwiftData relationships - CloudKit compatible
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSubcategory.category)
    var subcategories: [WorkoutSubcategory]? = []
    var workouts: [Workout]? = []
    
    init(name: String = "", color: String = "#FF0000", workoutType: WorkoutType? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.workoutType = workoutType
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
    

    
    // Get categories for a specific workout type
    static func categoriesForType(_ type: WorkoutType, from allCategories: [WorkoutCategory]) -> [WorkoutCategory] {
        return allCategories.filter { $0.workoutType == type }
    }
} 