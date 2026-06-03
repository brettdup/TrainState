import Foundation
import SwiftData

@Model
final class WorkoutSubcategoryRating {
    var id: UUID = UUID()
    var rating: Int = 5
    var workout: Workout?
    var subcategory: WorkoutSubcategory?

    init(
        rating: Int,
        workout: Workout? = nil,
        subcategory: WorkoutSubcategory? = nil
    ) {
        self.id = UUID()
        self.rating = min(max(rating, 1), 10)
        self.workout = workout
        self.subcategory = subcategory
    }
}
