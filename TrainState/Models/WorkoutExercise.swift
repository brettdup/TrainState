import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    // CloudKit requires defaults for non-optional attributes
    var name: String = ""
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var notes: String?
    var orderIndex: Int = 0
    
    @Relationship(inverse: \Workout.exercises)
    var workout: Workout?
    var subcategory: WorkoutSubcategory?
    
    init(
        name: String,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil,
        notes: String? = nil,
        orderIndex: Int = 0,
        workout: Workout? = nil,
        subcategory: WorkoutSubcategory? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.orderIndex = orderIndex
        self.workout = workout
        self.subcategory = subcategory
    }
}
