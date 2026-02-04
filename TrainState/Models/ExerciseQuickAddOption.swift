import Foundation

struct ExerciseQuickAddOption: Identifiable, Hashable {
    var id: String { "\(subcategoryID.uuidString)-\(name.lowercased())" }
    let name: String
    let subcategoryID: UUID
}
