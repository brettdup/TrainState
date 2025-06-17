import Foundation
import SwiftData

@Model
final class WorkoutSubcategory {
    var id: UUID = UUID()
    var name: String = ""
    
    // SwiftData relationships - CloudKit compatible
    var category: WorkoutCategory?
    var workouts: [Workout]? = []
    
    init(name: String = "") {
        self.id = UUID()
        self.name = name
    }
} 