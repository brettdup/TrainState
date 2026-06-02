import Foundation
import SwiftData
import WidgetKit

struct PendingQuickExerciseLog: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseName: String
    let loggedAt: Date
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let effortScore: Int?
    let subcategoryID: UUID?

    var summary: String {
        let weightText = weight.map { ExerciseLogEntry.displayWeight($0) + " kg" }
        let effortText = effortScore.map { "\($0)/10 tough" }
        return [exerciseName, setRepSummary, weightText, effortText].compactMap { $0 }.joined(separator: " - ")
    }

    init(
        id: UUID,
        exerciseName: String,
        loggedAt: Date,
        sets: Int?,
        reps: Int?,
        weight: Double?,
        effortScore: Int?,
        subcategoryID: UUID?
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.loggedAt = loggedAt
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.effortScore = effortScore
        self.subcategoryID = subcategoryID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case exerciseName
        case loggedAt
        case sets
        case reps
        case weight
        case effortScore
        case subcategoryID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        loggedAt = try container.decode(Date.self, forKey: .loggedAt)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        effortScore = try container.decodeIfPresent(Int.self, forKey: .effortScore)
        subcategoryID = try container.decodeIfPresent(UUID.self, forKey: .subcategoryID)
    }

    private var setRepSummary: String? {
        switch (sets, reps) {
        case let (.some(sets), .some(reps)) where sets > 0 && reps > 0:
            return "\(sets)x\(reps)"
        case let (.some(sets), _) where sets > 0:
            return "\(sets) set\(sets == 1 ? "" : "s")"
        case let (_, .some(reps)) where reps > 0:
            return "\(reps) reps"
        default:
            return nil
        }
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
    static func attachPendingLogs(
        to workouts: [Workout],
        availableSubcategories: [WorkoutSubcategory],
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
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
                effortScore: log.effortScore,
                notes: "Logged from widget on \(log.loggedAt.formatted(date: .abbreviated, time: .shortened))",
                orderIndex: nextOrderIndex,
                workout: workout,
                subcategory: linkedSubcategory(for: log, from: availableSubcategories)
            )

            if workout.exercises == nil {
                workout.exercises = []
            }
            workout.exercises?.append(exercise)
            if let subcategory = exercise.subcategory {
                workout.addSubcategory(subcategory)
                if let category = subcategory.category {
                    workout.addCategory(category)
                }
            }
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

    private static func linkedSubcategory(
        for log: PendingQuickExerciseLog,
        from subcategories: [WorkoutSubcategory]
    ) -> WorkoutSubcategory? {
        if let subcategoryID = log.subcategoryID {
            return subcategories.first { $0.id == subcategoryID }
        }

        return subcategories.first {
            $0.name.compare(log.exerciseName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
}
