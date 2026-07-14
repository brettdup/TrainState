import SwiftUI
import SwiftData
import UIKit

/// Unified exercise picker used across AddWorkout, EditWorkout, and LiveStrengthSession views.
/// Features search-first design, category filter chips, recent exercises, and multi-select support.
struct UnifiedExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]

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

    init(
        subcategories: [WorkoutSubcategory],
        exerciseOptions: [ExerciseQuickAddOption],
        existingExerciseNames: Set<String>,
        onSelect: @escaping ([ExerciseQuickAddOption]) -> Void,
        onCreateCustom: ((String, UUID) -> Void)? = nil,
        tintColor: Color = .accentColor
    ) {
        self.subcategories = subcategories
        self.exerciseOptions = exerciseOptions
        self.existingExerciseNames = existingExerciseNames
        self.onSelect = onSelect
        self.onCreateCustom = onCreateCustom
        self.tintColor = tintColor

        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 250
        _workouts = Query(descriptor)
    }

    // MARK: - Computed Properties

    private var subcategoryNameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: subcategories.map { ($0.id, $0.name) })
    }

    private var lastUsedDates: [String: Date] {
        cachedLastUsedDates
    }

    private var recentExercises: [ExerciseQuickAddOption] {
        // Filter cached recent exercises by current subcategory filter
        let availableOptionIDs = Set(exerciseOptions.map(\.id))
        let availableRecents = cachedRecentExercises.filter { availableOptionIDs.contains($0.id) }
        if let filterID = filterSubcategoryID {
            return availableRecents.filter { $0.subcategoryID == filterID }
        }
        return availableRecents
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
                let matchesAffectedSubcategory = affectedSubcategoryNames(for: option).contains {
                    $0.localizedCaseInsensitiveContains(trimmedSearch)
                }
                guard matchesName || matchesSubcategory || matchesAffectedSubcategory else { continue }
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

    private var remainingOptions: [ExerciseQuickAddOption] {
        guard searchText.isEmpty, filterSubcategoryID == nil else { return filteredOptions }
        let recentIDs = Set(recentExercises.map(\.id))
        return filteredOptions.filter { !recentIDs.contains($0.id) }
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
        !subcategories.isEmpty &&
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hasExactSearchMatch
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !subcategories.isEmpty {
                    categoryFilterRow
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                }

                List {
                    if exerciseOptions.isEmpty && !canCreateCustom {
                        emptyStateSection
                    } else if filteredOptions.isEmpty && !canCreateCustom {
                        noResultsSection
                    } else {
                        if !recentExercises.isEmpty && searchText.isEmpty && filterSubcategoryID == nil {
                            recentSection
                        }

                        if !remainingOptions.isEmpty {
                            Section(header: Text(exerciseSectionTitle)) {
                                ForEach(remainingOptions, id: \.id) { option in
                                    exerciseRow(for: option, showSubcategory: true)
                                }
                            }
                        }

                        if canCreateCustom {
                            createCustomSection
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 8, for: .scrollContent)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .animation(nil, value: selectedIDs)
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
            }
            .safeAreaInset(edge: .bottom) {
                if selectedCount > 0 {
                    selectionBar
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
                Text("No exercises yet")
                    .font(.subheadline.weight(.semibold))
                Text("Create one from search, or add exercises in your library.")
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
        Section {
            ForEach(recentExercises, id: \.id) { option in
                exerciseRow(for: option, showSubcategory: true, showLastUsed: true)
            }
        } header: {
            HStack {
                Text("Recent")
                Spacer()
                Text("Quick pick")
                    .textCase(nil)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
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

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", id: nil)

                ForEach(subcategories) { subcategory in
                    categoryChip(title: subcategory.name, id: subcategory.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(title: String, id: UUID?) -> some View {
        let isActive = filterSubcategoryID == id
        return Button {
            filterSubcategoryID = id
            HapticManager.lightImpact()
        } label: {
            Text(title)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? tintColor : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var selectionBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(selectedCount) selected")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Clear") {
                    selectedIDs.removeAll()
                }
                .font(.subheadline)
            }

            Button {
                onSelect(Array(selectedOptions))
                dismiss()
            } label: {
                Text(addButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tintColor)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
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
        let affectedSubcategoryNames = showSubcategory ? affectedSubcategoryNames(for: option) : []
        let lastUsed = showLastUsed ? lastUsedDates[option.id] : nil

        Button {
            toggleSelection(for: option)
        } label: {
            ExerciseRowView(
                option: option,
                subcategoryName: subcategoryName,
                affectedSubcategoryNames: affectedSubcategoryNames,
                isSelected: isSelected,
                lastUsed: lastUsed,
                tintColor: tintColor
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected ? tintColor.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground)
        )
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
        "Add \(selectedCount) Exercise\(selectedCount == 1 ? "" : "s")"
    }

    private var exerciseSectionTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Results"
        }
        if filterSubcategoryID != nil {
            return activeFilterTitle
        }
        return "All Exercises"
    }

    private var activeFilterTitle: String {
        filterSubcategoryID.flatMap { subcategoryNameByID[$0] } ?? "All Exercises"
    }

    private func affectedSubcategoryNames(for option: ExerciseQuickAddOption) -> [String] {
        guard let template = exerciseTemplates.first(where: {
            $0.subcategory?.id == option.subcategoryID &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(option.name) == .orderedSame
        }) else {
            return []
        }

        return template.secondarySubcategoryIDs
            .compactMap { subcategoryNameByID[$0] }
            .filter { $0.localizedCaseInsensitiveCompare(subcategoryNameByID[option.subcategoryID] ?? "") != .orderedSame }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
