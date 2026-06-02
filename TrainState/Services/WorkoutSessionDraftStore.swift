import Foundation

struct WorkoutSessionDraft: Codable, Equatable {
    var entries: [ExerciseLogEntry]
    var sessionStart: Date
    var isTimerRunning: Bool
    var updatedAt: Date
}

enum WorkoutSessionDraftStore {
    private static let storageKey = "workoutSessionDraft"

    static func load() -> WorkoutSessionDraft? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WorkoutSessionDraft.self, from: data)
    }

    static func save(_ draft: WorkoutSessionDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static var hasDraft: Bool {
        load() != nil
    }
}
