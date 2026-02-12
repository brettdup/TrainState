import Foundation

/// Utility to extract recently-used exercises from workout history.
struct RecentExercisesManager {
    /// Returns recently-used exercises from workout history, ordered by most recent use.
    /// - Parameters:
    ///   - workouts: Array of workouts to analyze
    ///   - limit: Maximum number of recent exercises to return
    ///   - filterSubcategoryIDs: Optional set of subcategory IDs to filter by
    /// - Returns: Array of ExerciseQuickAddOption for recent exercises
    static func getRecent(
        from workouts: [Workout],
        limit: Int = 10,
        filterSubcategoryIDs: Set<UUID>? = nil
    ) -> [ExerciseQuickAddOption] {
        var exerciseLastUsed: [String: (option: ExerciseQuickAddOption, date: Date)] = [:]

        // Process workouts from most recent to oldest
        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }

        for workout in sortedWorkouts {
            guard let exercises = workout.exercises else { continue }

            for exercise in exercises {
                guard let subcategory = exercise.subcategory else { continue }

                // Apply subcategory filter if provided
                if let filterIDs = filterSubcategoryIDs, !filterIDs.isEmpty {
                    guard filterIDs.contains(subcategory.id) else { continue }
                }

                let key = "\(subcategory.id.uuidString)-\(exercise.name.lowercased())"

                // Only record the most recent use of each exercise
                if exerciseLastUsed[key] == nil {
                    let option = ExerciseQuickAddOption(
                        name: exercise.name,
                        subcategoryID: subcategory.id
                    )
                    exerciseLastUsed[key] = (option: option, date: workout.startDate)
                }
            }
        }

        // Sort by most recent date and return limited results
        let sorted = exerciseLastUsed.values
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map(\.option)

        return Array(sorted)
    }

    /// Returns exercises with their last-used dates for display purposes.
    /// - Parameters:
    ///   - workouts: Array of workouts to analyze
    ///   - filterSubcategoryIDs: Optional set of subcategory IDs to filter by
    /// - Returns: Dictionary mapping exercise option IDs to their last-used dates
    static func getLastUsedDates(
        from workouts: [Workout],
        filterSubcategoryIDs: Set<UUID>? = nil
    ) -> [String: Date] {
        var lastUsedDates: [String: Date] = [:]

        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }

        for workout in sortedWorkouts {
            guard let exercises = workout.exercises else { continue }

            for exercise in exercises {
                guard let subcategory = exercise.subcategory else { continue }

                if let filterIDs = filterSubcategoryIDs, !filterIDs.isEmpty {
                    guard filterIDs.contains(subcategory.id) else { continue }
                }

                // Build the same ID format as ExerciseQuickAddOption
                let key = "\(subcategory.id.uuidString)-\(exercise.name.lowercased())"

                // Only record the most recent use
                if lastUsedDates[key] == nil {
                    lastUsedDates[key] = workout.startDate
                }
            }
        }

        return lastUsedDates
    }
}
