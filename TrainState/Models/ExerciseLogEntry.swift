import Foundation

struct ExerciseLogEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var subcategoryID: UUID?

    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        sets == nil &&
        reps == nil &&
        weight == nil
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
