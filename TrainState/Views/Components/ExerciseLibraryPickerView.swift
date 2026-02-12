import SwiftUI

/// Full-screen exercise picker used when editing a workout.
/// - Shows search, suggested exercises, and exercises grouped by subcategory.
/// - Allows multi-select and returns the chosen options on Done.
struct ExerciseLibraryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let subcategories: [WorkoutSubcategory]
    let options: [ExerciseQuickAddOption]
    let onDone: ([ExerciseQuickAddOption]) -> Void

    @State private var searchText: String = ""
    @State private var selectedIDs: Set<String> = []

    private var subcategoryNameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: subcategories.map { ($0.id, $0.name) })
    }

    private var dedupedOptions: [ExerciseQuickAddOption] {
        var seen: Set<String> = []
        var result: [ExerciseQuickAddOption] = []
        for option in options {
            let key = option.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(option)
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredOptions: [ExerciseQuickAddOption] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return dedupedOptions }
        return dedupedOptions.filter { option in
            option.name.localizedCaseInsensitiveContains(trimmed) ||
            (subcategoryNameByID[option.subcategoryID]?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var groupedBySubcategory: [(title: String, items: [ExerciseQuickAddOption])] {
        let grouped = Dictionary(grouping: filteredOptions) { option in
            subcategoryNameByID[option.subcategoryID] ?? "Other"
        }
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { key in
            (title: key, items: grouped[key]!.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    private var selectedOptions: [ExerciseQuickAddOption] {
        filteredOptions.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    Text("No exercises available yet. Add exercise templates in Categories first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 8)
                } else {
                    if !filteredOptions.isEmpty {
                        Section(header: Text("Suggestions")) {
                            ForEach(filteredOptions.prefix(8)) { option in
                                selectableRow(for: option, isInSuggestions: true)
                            }
                        }
                    }

                    ForEach(groupedBySubcategory, id: \.title) { group in
                        Section(header: Text(group.title)) {
                            ForEach(group.items) { option in
                                selectableRow(for: option, isInSuggestions: false)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneButtonTitle) {
                        onDone(Array(selectedOptions))
                        dismiss()
                    }
                    .disabled(selectedOptions.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func selectableRow(for option: ExerciseQuickAddOption, isInSuggestions: Bool) -> some View {
        let isSelected = selectedIDs.contains(option.id)

        Button {
            toggleSelection(for: option)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                    if !isInSuggestions, let subName = subcategoryNameByID[option.subcategoryID] {
                        Text(subName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func toggleSelection(for option: ExerciseQuickAddOption) {
        if selectedIDs.contains(option.id) {
            selectedIDs.remove(option.id)
        } else {
            selectedIDs.insert(option.id)
        }
    }

    private var doneButtonTitle: String {
        let count = selectedOptions.count
        guard count > 0 else { return "Add" }
        return "Add \(count)"
    }
}

