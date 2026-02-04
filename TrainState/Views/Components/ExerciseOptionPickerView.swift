import SwiftUI

struct ExerciseOptionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let options: [ExerciseQuickAddOption]
    let subcategories: [WorkoutSubcategory]
    let onSelect: (ExerciseQuickAddOption) -> Void

    private var subcategoryNameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: subcategories.map { ($0.id, $0.name) })
    }

    private var groupedOptions: [(title: String, items: [ExerciseQuickAddOption])] {
        let grouped = Dictionary(grouping: options) { option in
            subcategoryNameByID[option.subcategoryID] ?? "Exercises"
        }
        return grouped.keys.sorted().map { key in
            (title: key, items: grouped[key]!.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    Text("No exercises available. Add exercise templates in Categories first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groupedOptions, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.items) { option in
                                Button {
                                    onSelect(option)
                                    dismiss()
                                } label: {
                                    Text(option.name)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let strength = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
    let chest = WorkoutSubcategory(name: "Chest", category: strength)
    let legs = WorkoutSubcategory(name: "Legs", category: strength)

    return ExerciseOptionPickerView(
        options: [
            ExerciseQuickAddOption(name: "Bench Press", subcategoryID: chest.id),
            ExerciseQuickAddOption(name: "Incline Press", subcategoryID: chest.id),
            ExerciseQuickAddOption(name: "Back Squat", subcategoryID: legs.id)
        ],
        subcategories: [chest, legs],
        onSelect: { _ in }
    )
}
