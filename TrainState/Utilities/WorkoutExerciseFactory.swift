import Foundation
import SwiftData

enum WorkoutExerciseFactory {
    static func make(
        from entry: ExerciseLogEntry,
        orderIndex: Int,
        subcategories: [WorkoutSubcategory]
    ) -> WorkoutExercise? {
        let name = entry.trimmedName
        guard !name.isEmpty else { return nil }

        let linkedSubcategory = subcategories.first { $0.id == entry.subcategoryID }
        return WorkoutExercise(
            name: name,
            sets: entry.effectiveSetCount,
            reps: entry.effectiveReps,
            weight: entry.effectiveWeight,
            effortScore: entry.effortScore,
            notes: ExerciseSetPlanSerializer.notes(from: entry.setEntries),
            setPlanJSON: ExerciseSetPlanSerializer.encodeJSON(entry.setEntries),
            orderIndex: orderIndex,
            subcategory: linkedSubcategory
        )
    }
}
