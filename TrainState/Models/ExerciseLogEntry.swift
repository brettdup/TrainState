import Foundation

struct ExerciseSetEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var reps: Int = 0
    var weight: Double = 0
    var isCompleted: Bool = false

    var summary: String {
        let prefix = isCompleted ? "Done - " : ""
        return "\(prefix)\(reps) reps @ \(ExerciseLogEntry.displayWeight(weight)) kg"
    }
}

struct ExerciseLogEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var subcategoryID: UUID?
    var setEntries: [ExerciseSetEntry] = []

    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        sets == nil &&
        reps == nil &&
        weight == nil &&
        setEntries.isEmpty
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveSetCount: Int? {
        if !setEntries.isEmpty { return setEntries.count }
        return sets
    }

    var effectiveReps: Int? {
        if let first = setEntries.first, first.reps > 0 { return first.reps }
        return reps
    }

    var effectiveWeight: Double? {
        if let first = setEntries.first, first.weight > 0 { return first.weight }
        return weight
    }

    var setSummaryLines: [String] {
        guard !setEntries.isEmpty else { return [] }
        return setEntries.enumerated().map { idx, set in
            "Set \(idx + 1): \(set.summary)"
        }
    }

    var completedSetCount: Int {
        setEntries.filter(\.isCompleted).count
    }

    static func displayWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
