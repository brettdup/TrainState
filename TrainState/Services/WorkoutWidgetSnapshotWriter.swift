import Foundation
import WidgetKit

enum WorkoutWidgetSnapshotWriter {
    static let appGroupIdentifier = "group.brettduplessis.TrainState"
    static let snapshotKey = "weeklyWorkoutWidgetSnapshot"

    static func writeSnapshot(for workouts: [Workout]) {
        let snapshot = WorkoutWidgetSnapshot(workouts: workouts)
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyWorkoutSummaryWidget")
    }
}

struct WorkoutWidgetSnapshot: Codable {
    let workoutsThisWeek: Int
    let weeklyMinutes: Int
    let weeklyCalories: Int?
    let weeklyDistanceKilometers: Double
    let trainedDaysThisWeek: Int
    let currentStreak: Int
    let lastWorkoutTitle: String
    let typeBreakdown: [WorkoutWidgetTypeSummary]
    let updatedAt: Date

    init(
        workoutsThisWeek: Int,
        weeklyMinutes: Int,
        weeklyCalories: Int?,
        weeklyDistanceKilometers: Double,
        trainedDaysThisWeek: Int,
        currentStreak: Int,
        lastWorkoutTitle: String,
        typeBreakdown: [WorkoutWidgetTypeSummary],
        updatedAt: Date = Date()
    ) {
        self.workoutsThisWeek = workoutsThisWeek
        self.weeklyMinutes = weeklyMinutes
        self.weeklyCalories = weeklyCalories
        self.weeklyDistanceKilometers = weeklyDistanceKilometers
        self.trainedDaysThisWeek = trainedDaysThisWeek
        self.currentStreak = currentStreak
        self.lastWorkoutTitle = lastWorkoutTitle
        self.typeBreakdown = typeBreakdown
        self.updatedAt = updatedAt
    }

    init(workouts: [Workout], calendar: Calendar = .current, now: Date = Date()) {
        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekWorkouts = sortedWorkouts.filter { workout in
            weekInterval?.contains(workout.startDate) ?? false
        }
        let trainedDays = Set(weekWorkouts.map { calendar.startOfDay(for: $0.startDate) })

        workoutsThisWeek = weekWorkouts.count
        weeklyMinutes = Int(weekWorkouts.reduce(0) { $0 + $1.duration } / 60.0)
        weeklyCalories = Int(weekWorkouts.compactMap(\.calories).reduce(0, +))
        weeklyDistanceKilometers = weekWorkouts.compactMap(\.distance).reduce(0, +)
        trainedDaysThisWeek = trainedDays.count
        currentStreak = Self.currentDailyStreak(from: workouts, calendar: calendar, now: now)
        lastWorkoutTitle = sortedWorkouts.first?.primaryWorkoutDisplayName ?? "No workouts yet"
        typeBreakdown = Self.typeBreakdown(from: weekWorkouts)
        updatedAt = now
    }

    private static func typeBreakdown(from workouts: [Workout]) -> [WorkoutWidgetTypeSummary] {
        let grouped = Dictionary(grouping: workouts) { workout in
            workout.primaryWorkoutDisplayName
        }

        return grouped.map { title, workouts in
            let representative = workouts.first
            return WorkoutWidgetTypeSummary(
                title: title,
                systemImage: representative?.primaryWorkoutSystemImage ?? "figure.run",
                count: workouts.count
            )
        }
        .sorted {
            if $0.count == $1.count { return $0.title < $1.title }
            return $0.count > $1.count
        }
    }

    private static func currentDailyStreak(from workouts: [Workout], calendar: Calendar, now: Date) -> Int {
        let days = Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
           days.contains(yesterday) {
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }
}

struct WorkoutWidgetTypeSummary: Codable, Hashable {
    let title: String
    let systemImage: String
    let count: Int
}
