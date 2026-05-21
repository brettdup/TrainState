import Foundation
import SwiftData
import WidgetKit

struct PendingQuickExerciseLog: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseName: String
    let loggedAt: Date
    let sets: Int
    let reps: Int
    let weight: Double?

    var summary: String {
        let weightText = weight.map { ExerciseLogEntry.displayWeight($0) + " kg" }
        return [exerciseName, "\(sets)x\(reps)", weightText].compactMap { $0 }.joined(separator: " - ")
    }
}

enum QuickExerciseLogStore {
    static let appGroupIdentifier = "group.brettduplessis.TrainState"
    static let pendingLogsKey = "pendingQuickExerciseLogs"

    static func pendingLogs() -> [PendingQuickExerciseLog] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: pendingLogsKey),
              let logs = try? JSONDecoder().decode([PendingQuickExerciseLog].self, from: data) else {
            return []
        }
        return logs
    }

    static func savePendingLogs(_ logs: [PendingQuickExerciseLog]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(logs) else {
            return
        }
        defaults.set(data, forKey: pendingLogsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "QuickExerciseLogWidget")
    }

    static func appendPendingLog(_ log: PendingQuickExerciseLog) {
        var logs = pendingLogs()
        logs.append(log)
        savePendingLogs(logs)
    }

    @MainActor
    static func attachPendingLogs(to workouts: [Workout], in context: ModelContext, calendar: Calendar = .current) {
        let logs = pendingLogs()
        guard !logs.isEmpty, !workouts.isEmpty else { return }

        var remainingLogs: [PendingQuickExerciseLog] = []
        var didAttachLog = false

        for log in logs {
            guard let workout = matchingWorkout(for: log, in: workouts, calendar: calendar) else {
                remainingLogs.append(log)
                continue
            }

            let nextOrderIndex = ((workout.exercises ?? []).map(\.orderIndex).max() ?? -1) + 1
            let exercise = WorkoutExercise(
                name: log.exerciseName,
                sets: log.sets,
                reps: log.reps,
                weight: log.weight,
                notes: "Logged from widget on \(log.loggedAt.formatted(date: .abbreviated, time: .shortened))",
                orderIndex: nextOrderIndex,
                workout: workout
            )

            if workout.exercises == nil {
                workout.exercises = []
            }
            workout.exercises?.append(exercise)
            context.insert(exercise)
            didAttachLog = true
        }

        guard didAttachLog else { return }
        try? context.save()
        savePendingLogs(remainingLogs)
    }

    private static func matchingWorkout(for log: PendingQuickExerciseLog, in workouts: [Workout], calendar: Calendar) -> Workout? {
        workouts
            .filter { calendar.isDate($0.startDate, inSameDayAs: log.loggedAt) }
            .sorted { $0.startDate > $1.startDate }
            .first
    }
}
