import Foundation
import SwiftData

@Model
final class SubcategoryExercise {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    var subcategory: WorkoutSubcategory?

    init(name: String, subcategory: WorkoutSubcategory, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self.subcategory = subcategory
    }
}
