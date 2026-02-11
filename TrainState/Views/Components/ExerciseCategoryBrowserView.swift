import SwiftUI

/// Browses exercises by category and subcategory, for use while assigning
/// exercises during a workout (e.g. inside the exercise editor sheet).
struct ExerciseCategoryBrowserView: View {
    @Environment(\.dismiss) private var dismiss

    let subcategories: [WorkoutSubcategory]
    let options: [ExerciseQuickAddOption]
    let onSelect: (ExerciseQuickAddOption) -> Void

    private struct CategorySection: Identifiable {
        let id: UUID
        let name: String
        let workoutType: WorkoutType?
        let subcategories: [SubcategorySection]
    }

    private struct SubcategorySection: Identifiable {
        let id: UUID
        let name: String
        let exercises: [ExerciseQuickAddOption]
    }

    private var categorySections: [CategorySection] {
        // Group options by subcategory ID.
        let optionsBySubcategory = Dictionary(grouping: options, by: { $0.subcategoryID })

        // Build subcategory sections.
        let subSections: [UUID: SubcategorySection] = Dictionary(uniqueKeysWithValues: subcategories.map { sub in
            let exercises = optionsBySubcategory[sub.id] ?? []
            let sortedExercises = exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let section = SubcategorySection(id: sub.id, name: sub.name, exercises: sortedExercises)
            return (sub.id, section)
        })

        // Group subcategories by parent category.
        let groupedByCategory: [UUID: [SubcategorySection]] = subcategories.reduce(into: [:]) { result, sub in
            guard let category = sub.category else { return }
            let section = subSections[sub.id] ?? SubcategorySection(id: sub.id, name: sub.name, exercises: [])
            result[category.id, default: []].append(section)
        }

        // Build category sections with ordering.
        var categoriesByID: [UUID: WorkoutCategory] = [:]
        for sub in subcategories {
            if let category = sub.category {
                categoriesByID[category.id] = category
            }
        }

        var sections: [CategorySection] = []
        for (categoryID, subs) in groupedByCategory {
            guard let category = categoriesByID[categoryID] else { continue }
            let orderedSubs = subs.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            sections.append(
                CategorySection(
                    id: category.id,
                    name: category.name,
                    workoutType: category.workoutType,
                    subcategories: orderedSubs
                )
            )
        }

        // Sort categories by workout type then name for a stable, predictable layout.
        return sections.sorted { lhs, rhs in
            switch (lhs.workoutType, rhs.workoutType) {
            case let (l?, r?):
                if l == r {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return l.rawValue.localizedCaseInsensitiveCompare(r.rawValue) == .orderedAscending
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if categorySections.isEmpty {
                    Text("No exercises are available yet. Add categories, subcategories, and exercise templates in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(categorySections) { category in
                        Section(header: categoryHeader(for: category)) {
                            ForEach(category.subcategories) { sub in
                                if sub.exercises.isEmpty {
                                    // Show the subcategory itself as a single option when no templates exist.
                                    Button {
                                        let option = ExerciseQuickAddOption(name: sub.name, subcategoryID: sub.id)
                                        onSelect(option)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sub.name)
                                            Text("No templates yet")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    NavigationLink {
                                        ExerciseSubcategoryDetailView(
                                            subcategoryName: sub.name,
                                            options: sub.exercises,
                                            onSelect: { option in
                                                onSelect(option)
                                                dismiss()
                                            }
                                        )
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(sub.name)
                                                Text("\(sub.exercises.count) exercise\(sub.exercises.count == 1 ? "" : "s")")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Browse Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func categoryHeader(for category: CategorySection) -> some View {
        HStack(spacing: 6) {
            Text(category.name)
            if let type = category.workoutType {
                Text(type.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(type.tintColor.opacity(0.15))
                    )
            }
        }
    }
}

private struct ExerciseSubcategoryDetailView: View {
    let subcategoryName: String
    let options: [ExerciseQuickAddOption]
    let onSelect: (ExerciseQuickAddOption) -> Void

    var body: some View {
        List {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option.name)
                }
            }
        }
        .navigationTitle(subcategoryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

