import Foundation
import SwiftData

/// Builds workout category / subcategory assignments from logged exercise entries.
enum WorkoutClassificationBuilder {
    struct Classification {
        var categories: [WorkoutCategory]
        var subcategories: [WorkoutSubcategory]
    }

    static func build(
        from entries: [ExerciseLogEntry],
        subcategories allSubcategories: [WorkoutSubcategory]
    ) -> Classification {
        let subcategoryIDs = Set(entries.compactMap(\.subcategoryID))
        guard !subcategoryIDs.isEmpty else {
            return Classification(categories: [], subcategories: [])
        }

        var matchedSubcategories: [WorkoutSubcategory] = []
        var matchedCategories: [WorkoutCategory] = []
        var seenCategoryIDs = Set<UUID>()

        for id in subcategoryIDs {
            guard let subcategory = allSubcategories.first(where: { $0.id == id }) else { continue }
            matchedSubcategories.append(subcategory)

            if let category = subcategory.category, !seenCategoryIDs.contains(category.id) {
                seenCategoryIDs.insert(category.id)
                matchedCategories.append(category)
            }
        }

        let sortSubcategories: (WorkoutSubcategory, WorkoutSubcategory) -> Bool = {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let sortCategories: (WorkoutCategory, WorkoutCategory) -> Bool = {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return Classification(
            categories: matchedCategories.sorted(by: sortCategories),
            subcategories: matchedSubcategories.sorted(by: sortSubcategories)
        )
    }

    /// Fills missing subcategory IDs from the exercise library before classification.
    static func entriesWithInferredSubcategories(
        _ entries: [ExerciseLogEntry],
        exerciseTemplates: [SubcategoryExercise],
        quickAddOptions: [ExerciseQuickAddOption] = []
    ) -> [ExerciseLogEntry] {
        entries.map { entry in
            var updated = entry
            guard updated.subcategoryID == nil else { return updated }

            updated.subcategoryID = ExerciseSubcategoryMatcher.inferSubcategoryID(
                for: updated.trimmedName,
                templates: exerciseTemplates
            )

            if updated.subcategoryID == nil,
               let match = quickAddOptions.first(where: {
                   $0.name.caseInsensitiveCompare(updated.trimmedName) == .orderedSame
               }) {
                updated.subcategoryID = match.subcategoryID
            }

            return updated
        }
    }
}
