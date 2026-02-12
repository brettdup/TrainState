import Foundation
import SwiftData

struct TemplateSetPlanEntry: Codable, Hashable {
    let reps: Int
    let weight: Double
}

@Model
final class StrengthWorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var mainCategoryRawValue: String = WorkoutType.strength.rawValue

    @Relationship(deleteRule: .cascade, inverse: \StrengthWorkoutTemplateExercise.template)
    var exercises: [StrengthWorkoutTemplateExercise]? = []

    init(
        name: String,
        mainCategoryRawValue: String = WorkoutType.strength.rawValue,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        exercises: [StrengthWorkoutTemplateExercise] = []
    ) {
        self.id = UUID()
        self.name = name
        self.mainCategoryRawValue = mainCategoryRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exercises = exercises
    }
}

@Model
final class StrengthWorkoutTemplateExercise {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var subcategoryID: UUID?
    var setPlanJSON: String?

    var template: StrengthWorkoutTemplate?

    init(
        name: String,
        orderIndex: Int,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil,
        subcategoryID: UUID? = nil,
        setPlanJSON: String? = nil,
        template: StrengthWorkoutTemplate? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.subcategoryID = subcategoryID
        self.setPlanJSON = setPlanJSON
        self.template = template
    }
}

extension StrengthWorkoutTemplateExercise {
    func decodedSetPlan() -> [TemplateSetPlanEntry] {
        guard let setPlanJSON, let data = setPlanJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([TemplateSetPlanEntry].self, from: data)) ?? []
    }

    static func encodeSetPlan(_ entries: [TemplateSetPlanEntry]) -> String? {
        guard !entries.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(entries) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
