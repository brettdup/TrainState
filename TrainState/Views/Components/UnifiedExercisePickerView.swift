import SwiftUI
import SwiftData

/// Unified exercise picker used across AddWorkout, EditWorkout, and LiveStrengthSession views.
/// Features search-first design, category filter chips, recent exercises, and multi-select support.
struct UnifiedExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    let subcategories: [WorkoutSubcategory]
    let exerciseOptions: [ExerciseQuickAddOption]
    let existingExerciseNames: Set<String>
    let onSelect: ([ExerciseQuickAddOption]) -> Void
    var onCreateCustom: ((String, UUID) -> Void)?
    var tintColor: Color = .accentColor

    @State private var searchText = ""
    @State private var selectedIDs: Set<String> = []
    @State private var filterSubcategoryID: UUID?
    @State private var showingCustomExerciseSheet = false
    @State private var customExerciseName = ""

    // Cached data - computed once on appear to prevent reordering during session
    @State private var cachedRecentExercises: [ExerciseQuickAddOption] = []
    @State private var cachedLastUsedDates: [String: Date] = [:]
    @State private var hasLoadedCache = false

    // MARK: - Computed Properties

    private var subcategoryNameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: subcategories.map { ($0.id, $0.name) })
    }

    private var lastUsedDates: [String: Date] {
        cachedLastUsedDates
    }

    private var recentExercises: [ExerciseQuickAddOption] {
        // Filter cached recent exercises by current subcategory filter
        if let filterID = filterSubcategoryID {
            return cachedRecentExercises.filter { $0.subcategoryID == filterID }
        }
        return cachedRecentExercises
    }

    /// Deduplicated and filtered options based on search and category filters
    private var filteredOptions: [ExerciseQuickAddOption] {
        var seen: Set<String> = []
        var result: [ExerciseQuickAddOption] = []

        for option in exerciseOptions {
            // Apply subcategory filter
            if let filterID = filterSubcategoryID {
                guard option.subcategoryID == filterID else { continue }
            }

            // Dedupe by lowercase name
            let key = option.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            // Filter out already-added exercises
            guard !existingExerciseNames.contains(key) else { continue }

            // Apply search filter
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSearch.isEmpty {
                let matchesName = option.name.localizedCaseInsensitiveContains(trimmedSearch)
                let matchesSubcategory = subcategoryNameByID[option.subcategoryID]?
                    .localizedCaseInsensitiveContains(trimmedSearch) ?? false
                guard matchesName || matchesSubcategory else { continue }
            }

            result.append(option)
        }

        // Sort alphabetically by name, then by ID for stability
        return result.sorted {
            let nameComparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameComparison == .orderedSame {
                return $0.id < $1.id
            }
            return nameComparison == .orderedAscending
        }
    }

    /// Top suggestions (first 8 filtered options, excluding recent exercises to avoid duplicates)
    private var suggestions: [ExerciseQuickAddOption] {
        let recentIDs = Set(recentExercises.map(\.id))
        let nonRecentOptions = filteredOptions.filter { !recentIDs.contains($0.id) }
        return Array(nonRecentOptions.prefix(8))
    }

    /// Options grouped by subcategory (excluding items already shown in recent/suggestions when no chip selected)
    private var groupedBySubcategory: [(title: String, items: [ExerciseQuickAddOption])] {
        // When showing recent/suggestions, exclude those items from the grouped list
        var excludedIDs: Set<String> = []
        if filterSubcategoryID == nil {
            excludedIDs = Set(recentExercises.map(\.id)).union(Set(suggestions.map(\.id)))
        }
        let optionsToGroup = filteredOptions.filter { !excludedIDs.contains($0.id) }

        let grouped = Dictionary(grouping: optionsToGroup) { option in
            subcategoryNameByID[option.subcategoryID] ?? "Other"
        }
        return grouped.keys
            .sorted()
            .compactMap { key in
                let items = grouped[key]!.sorted {
                    let nameComparison = $0.name.localizedCaseInsensitiveCompare($1.name)
                    if nameComparison == .orderedSame {
                        return $0.id < $1.id
                    }
                    return nameComparison == .orderedAscending
                }
                return items.isEmpty ? nil : (title: key, items: items)
            }
    }

    private var selectedOptions: [ExerciseQuickAddOption] {
        exerciseOptions.filter { selectedIDs.contains($0.id) }
    }

    private var selectedCount: Int {
        selectedIDs.count
    }

    private var hasExactSearchMatch: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        return filteredOptions.contains { $0.name.lowercased() == trimmed }
    }

    private var canCreateCustom: Bool {
        onCreateCustom != nil &&
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hasExactSearchMatch
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                if !subcategories.isEmpty {
                    CategoryFilterChipsView(
                        subcategories: subcategories,
                        selectedID: $filterSubcategoryID,
                        tintColor: tintColor
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Main list
                List {
                    if exerciseOptions.isEmpty {
                        emptyStateSection
                    } else if filteredOptions.isEmpty && !canCreateCustom {
                        noResultsSection
                    } else {
                        // Recent exercises section (only when no chip selected)
                        if !recentExercises.isEmpty && searchText.isEmpty && filterSubcategoryID == nil {
                            recentSection
                        }

                        // Suggestions section (only when no chip selected)
                        if !suggestions.isEmpty && filterSubcategoryID == nil {
                            suggestionsSection
                        }

                        // Grouped by subcategory
                        ForEach(groupedBySubcategory, id: \.title) { group in
                            Section(header: Text(group.title)) {
                                ForEach(group.items, id: \.id) { option in
                                    exerciseRow(for: option, showSubcategory: false)
                                }
                            }
                        }

                        // Create custom option
                        if canCreateCustom {
                            createCustomSection
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(nil, value: selectedIDs)
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search exercises"
            )
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(addButtonTitle) {
                        onSelect(Array(selectedOptions))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCount == 0)
                }
            }
        }
        .sheet(isPresented: $showingCustomExerciseSheet) {
            customExerciseSubcategoryPicker
        }
        .onAppear {
            guard !hasLoadedCache else { return }
            hasLoadedCache = true

            // Cache recent exercises and last used dates once on appear
            let recent = RecentExercisesManager.getRecent(
                from: workouts,
                limit: 10,
                filterSubcategoryIDs: nil
            )
            cachedRecentExercises = recent.filter { !existingExerciseNames.contains($0.name.lowercased()) }
            cachedLastUsedDates = RecentExercisesManager.getLastUsedDates(
                from: workouts,
                filterSubcategoryIDs: nil
            )
        }
    }

    // MARK: - Sections

    private var emptyStateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("No exercises available")
                    .font(.subheadline.weight(.semibold))
                Text("Add exercise templates in Categories to build your library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private var noResultsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("No matching exercises")
                    .font(.subheadline.weight(.semibold))
                Text("Try a different search term or clear your filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private var recentSection: some View {
        Section(header: Text("Recent")) {
            ForEach(recentExercises, id: \.id) { option in
                exerciseRow(for: option, showSubcategory: true, showLastUsed: true)
            }
        }
    }

    private var suggestionsSection: some View {
        Section(header: Text("Suggestions")) {
            ForEach(suggestions, id: \.id) { option in
                exerciseRow(for: option, showSubcategory: true)
            }
        }
    }

    private var createCustomSection: some View {
        Section {
            Button {
                customExerciseName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                showingCustomExerciseSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(tintColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Add as a new custom exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func exerciseRow(
        for option: ExerciseQuickAddOption,
        showSubcategory: Bool,
        showLastUsed: Bool = false
    ) -> some View {
        let isSelected = selectedIDs.contains(option.id)
        let subcategoryName = showSubcategory ? subcategoryNameByID[option.subcategoryID] : nil
        let lastUsed = showLastUsed ? lastUsedDates[option.id] : nil

        Button {
            toggleSelection(for: option)
        } label: {
            ExerciseRowView(
                option: option,
                subcategoryName: subcategoryName,
                isSelected: isSelected,
                lastUsed: lastUsed,
                tintColor: tintColor
            )
        }
        .buttonStyle(.plain)
        .transaction { $0.animation = nil }
    }

    // MARK: - Custom Exercise Sheet

    private var customExerciseSubcategoryPicker: some View {
        NavigationStack {
            List {
                Section(header: Text("Select a category for \"\(customExerciseName)\"")) {
                    ForEach(subcategories) { subcategory in
                        Button {
                            onCreateCustom?(customExerciseName, subcategory.id)
                            showingCustomExerciseSheet = false
                            dismiss()
                        } label: {
                            HStack {
                                Text(subcategory.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomExerciseSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleSelection(for option: ExerciseQuickAddOption) {
        withAnimation(nil) {
            if selectedIDs.contains(option.id) {
                selectedIDs.remove(option.id)
            } else {
                selectedIDs.insert(option.id)
            }
        }
        HapticManager.lightImpact()
    }

    private var addButtonTitle: String {
        guard selectedCount > 0 else { return "Add" }
        return "Add \(selectedCount)"
    }
}

#Preview {
    let strength = WorkoutCategory(name: "Strength", color: "#FF9500", workoutType: .strength)
    let chest = WorkoutSubcategory(name: "Chest", category: strength)
    let back = WorkoutSubcategory(name: "Back", category: strength)
    let legs = WorkoutSubcategory(name: "Legs", category: strength)

    let options = [
        ExerciseQuickAddOption(name: "Bench Press", subcategoryID: chest.id),
        ExerciseQuickAddOption(name: "Incline Press", subcategoryID: chest.id),
        ExerciseQuickAddOption(name: "Cable Fly", subcategoryID: chest.id),
        ExerciseQuickAddOption(name: "Barbell Row", subcategoryID: back.id),
        ExerciseQuickAddOption(name: "Lat Pulldown", subcategoryID: back.id),
        ExerciseQuickAddOption(name: "Back Squat", subcategoryID: legs.id),
        ExerciseQuickAddOption(name: "Leg Press", subcategoryID: legs.id),
        ExerciseQuickAddOption(name: "Romanian Deadlift", subcategoryID: legs.id),
    ]

    return UnifiedExercisePickerView(
        subcategories: [chest, back, legs],
        exerciseOptions: options,
        existingExerciseNames: [],
        onSelect: { selected in
            print("Selected: \(selected.map(\.name))")
        },
        onCreateCustom: { name, subcategoryID in
            print("Create custom: \(name) in \(subcategoryID)")
        },
        tintColor: .orange
    )
}
