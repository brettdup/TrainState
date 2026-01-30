import Foundation
import SwiftData

@Model
final class WorkoutSubcategory {
    var id: UUID = UUID()
    var name: String = ""
    
    // SwiftData relationships - CloudKit compatible. Subcategory MUST be linked to a category.
    var category: WorkoutCategory?
    var workouts: [Workout]? = []

    /// Creates a subcategory linked to its parent category. A subcategory must always belong to a category.
    init(name: String, category: WorkoutCategory) {
        self.id = UUID()
        self.name = name
        self.category = category
        category.addSubcategory(self)
    }
} 