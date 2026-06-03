import Foundation
import SwiftData

@Model
final class SubcategoryExercise {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    var secondarySubcategoryIDStorage: String = ""
    var subcategory: WorkoutSubcategory?

    var secondarySubcategoryIDs: [UUID] {
        get {
            secondarySubcategoryIDStorage
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        }
        set {
            secondarySubcategoryIDStorage = newValue
                .map(\.uuidString)
                .joined(separator: ",")
        }
    }

    init(
        name: String,
        subcategory: WorkoutSubcategory,
        orderIndex: Int = 0,
        secondarySubcategoryIDs: [UUID] = []
    ) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self.secondarySubcategoryIDStorage = secondarySubcategoryIDs
            .map(\.uuidString)
            .joined(separator: ",")
        self.subcategory = subcategory
    }
}
