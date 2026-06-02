import Foundation
import SwiftData

enum ExerciseSessionActions {
    static func nextSetCompletionLabel(for entry: ExerciseLogEntry) -> String? {
        guard !entry.setEntries.isEmpty else { return nil }
        if entry.setEntries.contains(where: { !$0.isCompleted }) {
            if let nextIndex = entry.setEntries.firstIndex(where: { !$0.isCompleted }) {
                return "Set \(nextIndex + 1) done"
            }
        }
        return "Reset"
    }

    static func markNextSetDone(entry: inout ExerciseLogEntry) {
        if let nextIndex = entry.setEntries.firstIndex(where: { !$0.isCompleted }) {
            entry.setEntries[nextIndex].isCompleted = true
            HapticManager.lightImpact()
            return
        }

        for index in entry.setEntries.indices {
            entry.setEntries[index].isCompleted = false
        }
        HapticManager.lightImpact()
    }

    static func logNextSet(entry: inout ExerciseLogEntry, measurementSystem: MeasurementSystem) {
        if let last = entry.setEntries.last {
            var newSet = ExerciseSetEntry(reps: last.reps, weight: last.weight, isCompleted: true)
            if newSet.reps == 0, let reps = entry.effectiveReps { newSet.reps = reps }
            if newSet.weight == 0, let weight = entry.effectiveWeight { newSet.weight = weight }
            entry.setEntries.append(newSet)
        } else {
            let reps = entry.effectiveReps ?? 8
            let weight = entry.effectiveWeight ?? defaultWeight(for: measurementSystem)
            entry.setEntries = [ExerciseSetEntry(reps: reps, weight: weight, isCompleted: true)]
        }
        syncLegacyMetrics(&entry)
        HapticManager.lightImpact()
    }

    static func addSet(entry: inout ExerciseLogEntry, measurementSystem: MeasurementSystem) {
        if let last = entry.setEntries.last {
            entry.setEntries.append(ExerciseSetEntry(reps: last.reps, weight: last.weight))
        } else {
            entry.setEntries.append(
                ExerciseSetEntry(
                    reps: entry.effectiveReps ?? 8,
                    weight: entry.effectiveWeight ?? defaultWeight(for: measurementSystem)
                )
            )
        }
        syncLegacyMetrics(&entry)
    }

    static func prefill(
        entry: inout ExerciseLogEntry,
        workouts: [Workout],
        exerciseTemplates: [SubcategoryExercise]
    ) {
        let trimmedName = entry.trimmedName
        guard !trimmedName.isEmpty else { return }

        if entry.subcategoryID == nil {
            entry.subcategoryID = ExerciseSubcategoryMatcher.inferSubcategoryID(
                for: trimmedName,
                templates: exerciseTemplates
            )
        }

        guard entry.setEntries.isEmpty else { return }

        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        for workout in sortedWorkouts {
            guard let exercises = workout.exercises else { continue }
            guard let match = exercises.first(where: {
                $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            }) else { continue }

            let parsed = ExerciseSetPlanSerializer.setEntries(from: match)
            if !parsed.isEmpty {
                entry.setEntries = parsed.map {
                    ExerciseSetEntry(reps: $0.reps, weight: $0.weight, isCompleted: false)
                }
                syncLegacyMetrics(&entry)
                return
            }

            if let sets = match.sets, sets > 0 {
                let reps = match.reps ?? 8
                let weight = match.weight ?? 0
                entry.setEntries = (0..<sets).map { _ in
                    ExerciseSetEntry(reps: reps, weight: weight)
                }
                syncLegacyMetrics(&entry)
                return
            }
        }
    }

    static func syncLegacyMetrics(_ entry: inout ExerciseLogEntry) {
        entry.sets = entry.setEntries.isEmpty ? entry.sets : entry.setEntries.count
        if let first = entry.setEntries.first {
            entry.reps = first.reps
            entry.weight = first.weight
        }
    }

    private static func defaultWeight(for system: MeasurementSystem) -> Double {
        system == .imperial ? 45 / 2.20462 : 20
    }
}

enum ExerciseSubcategoryMatcher {
    static func inferSubcategoryID(
        for exerciseName: String,
        templates: [SubcategoryExercise]
    ) -> UUID? {
        let normalized = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let exact = templates.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }) {
            return exact.subcategory?.id
        }

        if let contains = templates.first(where: {
            let templateName = $0.name.lowercased()
            return templateName.contains(normalized) || normalized.contains(templateName)
        }) {
            return contains.subcategory?.id
        }

        return nil
    }
}
