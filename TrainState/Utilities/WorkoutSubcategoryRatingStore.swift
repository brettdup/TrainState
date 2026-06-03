import Foundation
import SwiftData

enum WorkoutSubcategoryRatingStore {
    static func ratingsBySubcategoryID(for workout: Workout) -> [UUID: Int] {
        var ratings: [UUID: Int] = [:]
        for rating in workout.subcategoryRatings ?? [] {
            guard let subcategoryID = rating.subcategory?.id else { continue }
            ratings[subcategoryID] = min(max(rating.rating, 1), 10)
        }
        return ratings
    }

    static func makeRatings(
        from ratingsBySubcategoryID: [UUID: Int],
        subcategories: [WorkoutSubcategory],
        workout: Workout? = nil
    ) -> [WorkoutSubcategoryRating] {
        var subcategoriesByID: [UUID: WorkoutSubcategory] = [:]
        for subcategory in subcategories {
            subcategoriesByID[subcategory.id] = subcategory
        }
        return ratingsBySubcategoryID.compactMap { subcategoryID, score in
            guard let subcategory = subcategoriesByID[subcategoryID] else { return nil }
            return WorkoutSubcategoryRating(
                rating: score,
                workout: workout,
                subcategory: subcategory
            )
        }
    }

    static func replaceRatings(
        on workout: Workout,
        with ratingsBySubcategoryID: [UUID: Int],
        subcategories: [WorkoutSubcategory],
        modelContext: ModelContext
    ) {
        (workout.subcategoryRatings ?? []).forEach { modelContext.delete($0) }
        let models = makeRatings(
            from: ratingsBySubcategoryID,
            subcategories: subcategories,
            workout: workout
        )
        models.forEach { modelContext.insert($0) }
        workout.subcategoryRatings = models
    }
}
