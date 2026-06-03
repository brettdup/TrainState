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
        subcategories allSubcategories: [WorkoutSubcategory],
        exerciseTemplates: [SubcategoryExercise] = []
    ) -> Classification {
        let subcategoryIDs = Set(entries.flatMap { entry in
            classificationSubcategoryIDs(
                for: entry,
                allSubcategories: allSubcategories,
                exerciseTemplates: exerciseTemplates
            )
        })
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

    private static func classificationSubcategoryIDs(
        for entry: ExerciseLogEntry,
        allSubcategories: [WorkoutSubcategory],
        exerciseTemplates: [SubcategoryExercise]
    ) -> [UUID] {
        guard let primaryID = entry.subcategoryID else { return [] }
        let trimmedName = entry.trimmedName
        guard !trimmedName.isEmpty else { return [primaryID] }

        guard let template = exerciseTemplates.first(where: {
            $0.subcategory?.id == primaryID &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedName) == .orderedSame
        }) else {
            return [primaryID]
        }

        let secondaryIDs = compatibleSecondarySubcategoryIDs(
            template.secondarySubcategoryIDs,
            primaryID: primaryID,
            allSubcategories: allSubcategories
        )
        return [primaryID] + secondaryIDs
    }

    private static func compatibleSecondarySubcategoryIDs(
        _ secondaryIDs: [UUID],
        primaryID: UUID,
        allSubcategories: [WorkoutSubcategory]
    ) -> [UUID] {
        guard let primarySubcategory = allSubcategories.first(where: { $0.id == primaryID }),
              let primaryWorkoutType = primarySubcategory.category?.resolvedWorkoutType else {
            return []
        }

        return secondaryIDs.filter { id in
            guard id != primaryID,
                  let secondarySubcategory = allSubcategories.first(where: { $0.id == id }) else {
                return false
            }
            return secondarySubcategory.category?.resolvedWorkoutType == primaryWorkoutType
        }
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
