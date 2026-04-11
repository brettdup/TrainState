import SwiftUI
import SwiftData
import CoreLocation
import HealthKit

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSubcategory.name) private var allSubcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Bindable var workout: Workout
    @Query(sort: \StrengthWorkoutTemplate.updatedAt, order: .reverse) private var strengthTemplates: [StrengthWorkoutTemplate]
    @State private var showingDeleteConfirmation = false
    @State private var showingRouteMapSheet = false
    @State private var showingSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var showingExercisePicker = false
    @State private var showingExerciseEditor = false
    @State private var showingCategoryAssignment = false
    @State private var editingExerciseID: UUID?
    @State private var exerciseDraftEntry = ExerciseLogEntry()
    @State private var originalExerciseDraftEntry = ExerciseLogEntry()
    @State private var exerciseInsightTarget: ExerciseInsightTarget?
    @State private var pendingExerciseSaveTask: Task<Void, Never>?
    @State private var pendingCategoryAssignmentSaveTask: Task<Void, Never>?
    @State private var selectedCategoriesForAssignment: [WorkoutCategory] = []
    @State private var selectedSubcategoriesForAssignment: [WorkoutSubcategory] = []
    @State private var showingCategoriesManagement = false

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.primaryWorkoutDisplayName)
                            .font(.headline)
                        Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let detailSummary {
                            Text(detailSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let headerClassificationSummary {
                            Text(headerClassificationSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: workout.primaryWorkoutSystemImage)
                        .foregroundStyle(workout.primaryWorkoutTintColor)
                }
            }

            WorkoutStructureSection(
                title: "Categories",
                primaryActionTitle: hasClassificationDetails ? "Edit Categories" : "Add Categories",
                primaryActionSubtitle: hasClassificationDetails ? "Update linked categories and subcategories" : "Assign categories to this workout",
                primaryAction: prepareCategoryAssignment,
                secondaryActionTitle: workout.type == .strength ? "Manage Exercise Library" : nil,
                secondaryActionSubtitle: workout.type == .strength ? "Edit categories, subcategories, and exercise templates" : nil,
                secondaryAction: workout.type == .strength ? { showingCategoriesManagement = true } : nil,
                categoryItems: [],
                subcategoryItems: [],
                emptyStateText: ""
            )

            Section {
                addExercisesButton

                if let exercises = workout.exercises, !exercises.isEmpty {
                    ForEach(exercises.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { exercise in
                        Button {
                            openExerciseEditor(for: exercise)
                        } label: {
                            ExerciseCardView(
                                exercise: exercise,
                                showChevron: false,
                                colorScheme: .light
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                openExerciseEditor(for: exercise)
                            } label: {
                                Label("Add Sets", systemImage: "plus.circle")
                            }

                            Button {
                                exerciseInsightTarget = ExerciseInsightTarget(
                                    id: exercise.id,
                                    exerciseName: exercise.name,
                                    subcategoryID: exercise.subcategory?.id
                                )
                            } label: {
                                Label("View Exercise Page", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                    }
                }
            } header: {
                Text("Exercises")
            } footer: {
                if workout.exercises?.isEmpty == false {
                    Text("Tap an exercise to view its recent performance.")
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                Section {
                    Text(notes)
                } header: {
                    Text("Notes")
                }
            }

            if let route = workout.route?.decodedRoute, !route.isEmpty {
                Section {
                    RouteMapView(route: route)
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingRouteMapSheet = true
                        }

                    Button("Open Route Map") {
                        showingRouteMapSheet = true
                    }
                } header: {
                    Text("Route")
                }
            }

            Section {
                NavigationLink {
                    EditWorkoutView(workout: workout)
                } label: {
                    Text("Edit Workout")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    EditWorkoutView(workout: workout)
                } label: {
                    Image(systemName: "pencil")
                }

                Menu {
                    if canSaveAsStrengthTemplate {
                        Button {
                            templateName = defaultTemplateName
                            showingSaveTemplateAlert = true
                        } label: {
                            Label("Save as Template", systemImage: "square.and.arrow.down")
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete Workout", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This workout will be permanently deleted. This action cannot be undone.")
        }
        .alert("Save as Template", isPresented: $showingSaveTemplateAlert) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {
                templateName = ""
            }
            Button("Save") {
                saveWorkoutAsTemplate()
                templateName = ""
            }
            .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Save this workout's exercises as a reusable strength template.")
        }
        .sheet(isPresented: $showingRouteMapSheet) {
            if let route = workout.route?.decodedRoute, !route.isEmpty {
                RouteMapSheetView(route: route)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            UnifiedExercisePickerView(
                subcategories: availableExerciseSubcategories,
                exerciseOptions: quickAddOptions,
                existingExerciseNames: Set((workout.exercises ?? []).map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }),
                onSelect: { selected in
                    for option in selected {
                        addExerciseToWorkout(from: option)
                    }
                },
                onCreateCustom: { name, subcategoryID in
                    addCustomExerciseToWorkout(name: name, subcategoryID: subcategoryID)
                },
                tintColor: workout.primaryWorkoutTintColor
            )
        }
        .sheet(isPresented: $showingExerciseEditor) {
            ExerciseEditorSheetView(
                entry: $exerciseDraftEntry,
                availableSubcategories: availableExerciseSubcategories,
                availableOptions: quickAddOptions,
                onDelete: {
                    deleteEditedExercise()
                }
            )
        }
        .sheet(isPresented: $showingCategoryAssignment) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategoriesForAssignment,
                selectedSubcategories: $selectedSubcategoriesForAssignment,
                workoutType: workout.type,
                appleWorkoutActivityType: workout.appleWorkoutActivityType,
                lockedSubcategoryIDs: Set((workout.exercises ?? []).compactMap { $0.subcategory?.id })
            )
        }
        .sheet(isPresented: $showingCategoriesManagement) {
            NavigationStack {
                CategoriesManagementView()
            }
        }
        .onChange(of: exerciseDraftEntry) { _, _ in
            scheduleEditedExercisePersistence()
        }
        .onChange(of: showingExerciseEditor) { _, isPresented in
            if !isPresented {
                pendingExerciseSaveTask?.cancel()
                pendingExerciseSaveTask = nil
                persistEditedExerciseIfNeeded(saveToStore: false)
                editingExerciseID = nil
            }
        }
        .onChange(of: showingCategoryAssignment) { _, isPresented in
            if !isPresented {
                pendingCategoryAssignmentSaveTask?.cancel()
                pendingCategoryAssignmentSaveTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    applyCategoryAssignment()
                }
            }
        }
        .navigationDestination(item: $exerciseInsightTarget) { target in
            ExerciseInsightsView(
                exerciseName: target.exerciseName,
                subcategoryID: target.subcategoryID
            )
        }
    }

    private var addExercisesButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(workout.primaryWorkoutTintColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Exercises")
                        .font(.subheadline.weight(.semibold))
                    Text("Search and select from your library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var availableExerciseSubcategories: [WorkoutSubcategory] {
        allSubcategories.filter { subcategory in
            guard let category = subcategory.category else { return false }
            return category.matches(
                appleWorkoutActivityType: workout.resolvedAppleWorkoutActivityType,
                fallbackWorkoutType: workout.type
            )
        }
    }

    private var quickAddOptions: [ExerciseQuickAddOption] {
        var options: [ExerciseQuickAddOption] = []
        for subcategory in availableExerciseSubcategories {
            let templates = exerciseTemplates
                .filter { $0.subcategory?.id == subcategory.id }
                .sorted { $0.orderIndex < $1.orderIndex }
            if templates.isEmpty {
                options.append(ExerciseQuickAddOption(name: subcategory.name, subcategoryID: subcategory.id))
            } else {
                options.append(contentsOf: templates.map {
                    ExerciseQuickAddOption(name: $0.name, subcategoryID: subcategory.id)
                })
            }
        }
        return options
    }

    private var detailSummary: String? {
        var parts: [String] = []

        if workout.duration > 0 {
            parts.append(formattedDuration(workout.duration))
        }

        if let distance = workout.distance, distance > 0 {
            parts.append(String(format: "%.1f km", distance))
        }

        if let calories = workout.calories, calories > 0 {
            parts.append("\(Int(calories)) kcal")
        }

        if let rating = workout.rating, rating > 0 {
            parts.append(String(format: "%.1f/10", rating))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func prepareCategoryAssignment() {
        pendingCategoryAssignmentSaveTask?.cancel()
        selectedCategoriesForAssignment = workout.categories ?? []
        selectedSubcategoriesForAssignment = workout.subcategories ?? []
        showingCategoryAssignment = true
    }

    private func applyCategoryAssignment() {
        workout.categories = selectedCategoriesForAssignment
        workout.subcategories = selectedSubcategoriesForAssignment
        try? modelContext.save()
    }

    private var categoryDetails: [WorkoutStructureSummaryItem] {
        let items = (workout.categories ?? []).compactMap { category -> WorkoutStructureSummaryItem? in
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return WorkoutStructureSummaryItem(
                title: name,
                tint: Color(hex: category.color) ?? workout.primaryWorkoutTintColor,
                symbol: "folder.fill"
            )
        }
        return uniqueClassificationItems(items)
    }

    private var subcategoryDetails: [WorkoutStructureSummaryItem] {
        let items = (workout.subcategories ?? []).compactMap { subcategory -> WorkoutStructureSummaryItem? in
            let name = subcategory.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let tint = subcategory.category.flatMap { Color(hex: $0.color) } ?? workout.primaryWorkoutTintColor
            return WorkoutStructureSummaryItem(
                title: name,
                tint: tint,
                symbol: "tag.fill"
            )
        }
        return uniqueClassificationItems(items)
    }

    private var hasClassificationDetails: Bool {
        !categoryDetails.isEmpty || !subcategoryDetails.isEmpty
    }

    private var headerClassificationSummary: String? {
        let categoryText = categoryDetails.map(\.title).joined(separator: ", ")
        let subcategoryText = subcategoryDetails.map(\.title).joined(separator: ", ")
        let parts = [categoryText, subcategoryText].filter { !$0.isEmpty }
        let summary = parts.joined(separator: " · ")
        return summary.isEmpty ? nil : summary
    }

    private func uniqueClassificationItems(_ items: [WorkoutStructureSummaryItem]) -> [WorkoutStructureSummaryItem] {
        var seen = Set<String>()
        return items.filter { item in
            seen.insert(item.id).inserted
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }

    private func deleteWorkout() {
        modelContext.delete(workout)
        try? modelContext.save()
    }

    private var canSaveAsStrengthTemplate: Bool {
        workout.type == .strength && !(workout.exercises?.isEmpty ?? true)
    }

    private var defaultTemplateName: String {
        let base = "Strength \(workout.startDate.formatted(date: .abbreviated, time: .omitted))"
        let existingNames = Set(strengthTemplates.map { $0.name.lowercased() })
        if !existingNames.contains(base.lowercased()) {
            return base
        }
        var suffix = 2
        while existingNames.contains("\(base) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    private func saveWorkoutAsTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let sortedWorkoutExercises = (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let templateExercises = sortedWorkoutExercises.enumerated().map { index, exercise in
            StrengthWorkoutTemplateExercise(
                name: exercise.name,
                orderIndex: index,
                sets: exercise.sets,
                reps: exercise.reps,
                weight: exercise.weight,
                subcategoryID: exercise.subcategory?.id
            )
        }
        guard !templateExercises.isEmpty else { return }

        if let existing = strengthTemplates.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            existing.name = name
            existing.mainCategoryRawValue = workout.type.rawValue
            existing.appleWorkoutActivityType = workout.appleWorkoutActivityType ?? workout.type.defaultAppleWorkoutActivityType
            existing.updatedAt = Date()
            existing.exercises = templateExercises
        } else {
            let template = StrengthWorkoutTemplate(
                name: name,
                mainCategoryRawValue: workout.type.rawValue,
                appleWorkoutActivityType: workout.appleWorkoutActivityType ?? workout.type.defaultAppleWorkoutActivityType,
                exercises: templateExercises
            )
            modelContext.insert(template)
        }
        try? modelContext.save()
    }

    private func addExerciseToWorkout(from option: ExerciseQuickAddOption) {
        let nextOrderIndex = ((workout.exercises ?? []).map(\.orderIndex).max() ?? -1) + 1
        let linkedSubcategory = allSubcategories.first { $0.id == option.subcategoryID }
        syncWorkoutClassification(for: linkedSubcategory)
        let previousMatch = (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .last { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(option.name) == .orderedSame }

        let exercise = WorkoutExercise(
            name: option.name,
            sets: previousMatch?.sets,
            reps: previousMatch?.reps,
            weight: previousMatch?.weight,
            notes: previousMatch?.notes,
            orderIndex: nextOrderIndex,
            workout: workout,
            subcategory: linkedSubcategory
        )

        if workout.exercises == nil {
            workout.exercises = []
        }
        workout.exercises?.append(exercise)
        modelContext.insert(exercise)
        try? modelContext.save()
    }

    private func addCustomExerciseToWorkout(name: String, subcategoryID: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addExerciseToWorkout(from: ExerciseQuickAddOption(name: trimmed, subcategoryID: subcategoryID))
    }

    private func syncWorkoutClassification(for subcategory: WorkoutSubcategory?) {
        guard let subcategory else { return }

        if workout.subcategories == nil {
            workout.subcategories = []
        }
        if !(workout.subcategories?.contains(where: { $0.id == subcategory.id }) ?? false) {
            workout.subcategories?.append(subcategory)
        }

        if let category = subcategory.category {
            if workout.categories == nil {
                workout.categories = []
            }
            if !(workout.categories?.contains(where: { $0.id == category.id }) ?? false) {
                workout.categories?.append(category)
            }
        }
    }

    private func openExerciseEditor(for exercise: WorkoutExercise) {
        pendingExerciseSaveTask?.cancel()
        pendingExerciseSaveTask = nil
        editingExerciseID = exercise.id
        let draft = ExerciseLogEntry(
            id: exercise.id,
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            weight: exercise.weight,
            subcategoryID: exercise.subcategory?.id,
            setEntries: Self.parseSetEntries(from: exercise.notes)
        )
        exerciseDraftEntry = draft
        originalExerciseDraftEntry = draft
        showingExerciseEditor = true
    }

    private func scheduleEditedExercisePersistence() {
        guard showingExerciseEditor, editingExerciseID != nil else { return }

        pendingExerciseSaveTask?.cancel()
        pendingExerciseSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            persistEditedExerciseIfNeeded(saveToStore: true)
        }
    }

    private func persistEditedExerciseIfNeeded(saveToStore: Bool) {
        guard let editingExerciseID,
              let exercise = workout.exercises?.first(where: { $0.id == editingExerciseID }) else {
            if !showingExerciseEditor {
                self.editingExerciseID = nil
            }
            return
        }

        guard exerciseDraftEntry != originalExerciseDraftEntry else {
            if !showingExerciseEditor {
                self.editingExerciseID = nil
            }
            return
        }

        exercise.name = exerciseDraftEntry.trimmedName
        exercise.sets = exerciseDraftEntry.sets
        exercise.reps = exerciseDraftEntry.reps
        exercise.weight = exerciseDraftEntry.weight
        exercise.notes = exerciseNotes(for: exerciseDraftEntry)
        exercise.subcategory = allSubcategories.first { $0.id == exerciseDraftEntry.subcategoryID }
        if saveToStore {
            try? modelContext.save()
        }
        originalExerciseDraftEntry = exerciseDraftEntry
        if !showingExerciseEditor {
            self.editingExerciseID = nil
        }
    }

    private func deleteEditedExercise() {
        guard let editingExerciseID,
              let exercise = workout.exercises?.first(where: { $0.id == editingExerciseID }) else {
            self.editingExerciseID = nil
            return
        }

        workout.exercises?.removeAll { $0.id == editingExerciseID }
        modelContext.delete(exercise)
        try? modelContext.save()
        self.editingExerciseID = nil
    }

    private func exerciseNotes(for entry: ExerciseLogEntry) -> String? {
        let lines = entry.setSummaryLines
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private static func parseSetEntries(from notes: String?) -> [ExerciseSetEntry] {
        guard let notes, !notes.isEmpty else { return [] }

        return notes
            .split(separator: "\n")
            .compactMap { parseSetEntry(from: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func parseSetEntry(from line: String) -> ExerciseSetEntry? {
        guard let separator = line.range(of: ": ") else { return nil }

        let detail = String(line[separator.upperBound...])
        let isCompleted = detail.hasPrefix("Done - ")
        let normalizedDetail = isCompleted ? String(detail.dropFirst("Done - ".count)) : detail

        let pattern = #"^\s*(\d+)\s+reps\s+@\s+([0-9]+(?:\.[0-9]+)?)\s+kg\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: normalizedDetail,
                range: NSRange(normalizedDetail.startIndex..., in: normalizedDetail)
              ),
              let repsRange = Range(match.range(at: 1), in: normalizedDetail),
              let weightRange = Range(match.range(at: 2), in: normalizedDetail),
              let reps = Int(normalizedDetail[repsRange]),
              let weight = Double(normalizedDetail[weightRange]) else {
            return nil
        }

        return ExerciseSetEntry(reps: reps, weight: weight, isCompleted: isCompleted)
    }
}

private struct ExerciseInsightTarget: Identifiable, Hashable {
    let id: UUID
    let exerciseName: String
    let subcategoryID: UUID?
}

@MainActor
private func makeWorkoutDetailPreviewData() -> (container: ModelContainer, workout: Workout) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self, configurations: config)
    let context = container.mainContext

    let upperBody = WorkoutCategory(
        name: "Upper Body",
        color: "#FF6B6B",
        workoutType: .strength,
        appleWorkoutActivityType: .traditionalStrengthTraining
    )
    let lowerBody = WorkoutCategory(
        name: "Lower Body",
        color: "#4ECDC4",
        workoutType: .strength,
        appleWorkoutActivityType: .traditionalStrengthTraining
    )
    context.insert(upperBody)
    context.insert(lowerBody)

    let chest = WorkoutSubcategory(name: "Chest", category: upperBody)
    let shoulders = WorkoutSubcategory(name: "Shoulders", category: upperBody)
    let triceps = WorkoutSubcategory(name: "Triceps", category: upperBody)
    let back = WorkoutSubcategory(name: "Back", category: upperBody)
    let quads = WorkoutSubcategory(name: "Quads", category: lowerBody)
    let hamstrings = WorkoutSubcategory(name: "Hamstrings", category: lowerBody)
    let glutes = WorkoutSubcategory(name: "Glutes", category: lowerBody)

    [chest, shoulders, triceps, back, quads, hamstrings, glutes].forEach { context.insert($0) }

    let workout = Workout(
        type: .strength,
        startDate: .now.addingTimeInterval(-5400),
        duration: 5820,
        calories: 684,
        rating: 8.7,
        notes: "Heavy upper/lower split with a focus on compound lifts and accessory volume.",
        categories: [upperBody, lowerBody],
        subcategories: [chest, shoulders, triceps, back, quads, hamstrings, glutes],
        hkActivityTypeRaw: Int(HKWorkoutActivityType.traditionalStrengthTraining.rawValue)
    )
    context.insert(workout)

    let exercises = [
        WorkoutExercise(
            name: "Barbell Bench Press",
            sets: 4,
            reps: 6,
            weight: 95,
            notes: """
            Set 1: Done - 6 reps @ 95 kg
            Set 2: Done - 6 reps @ 95 kg
            Set 3: Done - 5 reps @ 97.5 kg
            Set 4: 4 reps @ 97.5 kg
            """,
            orderIndex: 0,
            workout: workout,
            subcategory: chest
        ),
        WorkoutExercise(
            name: "Incline Dumbbell Press",
            sets: 3,
            reps: 10,
            weight: 34,
            notes: """
            Set 1: Done - 10 reps @ 34 kg
            Set 2: Done - 9 reps @ 34 kg
            Set 3: 8 reps @ 34 kg
            """,
            orderIndex: 1,
            workout: workout,
            subcategory: chest
        ),
        WorkoutExercise(
            name: "Seated Dumbbell Shoulder Press",
            sets: 4,
            reps: 8,
            weight: 26,
            notes: """
            Set 1: Done - 8 reps @ 26 kg
            Set 2: Done - 8 reps @ 26 kg
            Set 3: Done - 7 reps @ 28 kg
            Set 4: 6 reps @ 28 kg
            """,
            orderIndex: 2,
            workout: workout,
            subcategory: shoulders
        ),
        WorkoutExercise(
            name: "Weighted Dips",
            sets: 3,
            reps: 10,
            weight: 20,
            notes: """
            Set 1: Done - 10 reps @ 20 kg
            Set 2: Done - 10 reps @ 20 kg
            Set 3: 8 reps @ 22.5 kg
            """,
            orderIndex: 3,
            workout: workout,
            subcategory: triceps
        ),
        WorkoutExercise(
            name: "Chest-Supported Row",
            sets: 4,
            reps: 12,
            weight: 55,
            notes: """
            Set 1: Done - 12 reps @ 55 kg
            Set 2: Done - 12 reps @ 55 kg
            Set 3: Done - 11 reps @ 57.5 kg
            Set 4: 10 reps @ 57.5 kg
            """,
            orderIndex: 4,
            workout: workout,
            subcategory: back
        ),
        WorkoutExercise(
            name: "Back Squat",
            sets: 5,
            reps: 5,
            weight: 130,
            notes: """
            Set 1: Done - 5 reps @ 120 kg
            Set 2: Done - 5 reps @ 125 kg
            Set 3: Done - 5 reps @ 130 kg
            Set 4: Done - 5 reps @ 130 kg
            Set 5: 4 reps @ 132.5 kg
            """,
            orderIndex: 5,
            workout: workout,
            subcategory: quads
        ),
        WorkoutExercise(
            name: "Romanian Deadlift",
            sets: 4,
            reps: 8,
            weight: 110,
            notes: """
            Set 1: Done - 8 reps @ 100 kg
            Set 2: Done - 8 reps @ 105 kg
            Set 3: Done - 8 reps @ 110 kg
            Set 4: 7 reps @ 110 kg
            """,
            orderIndex: 6,
            workout: workout,
            subcategory: hamstrings
        ),
        WorkoutExercise(
            name: "Barbell Hip Thrust",
            sets: 4,
            reps: 10,
            weight: 140,
            notes: """
            Set 1: Done - 10 reps @ 130 kg
            Set 2: Done - 10 reps @ 135 kg
            Set 3: Done - 10 reps @ 140 kg
            Set 4: 9 reps @ 140 kg
            """,
            orderIndex: 7,
            workout: workout,
            subcategory: glutes
        )
    ]

    exercises.forEach { exercise in
        context.insert(exercise)
    }
    workout.exercises = exercises

    return (container, workout)
}

#Preview {
    let preview = makeWorkoutDetailPreviewData()

    NavigationStack {
        WorkoutDetailView(workout: preview.workout)
    }
    .modelContainer(preview.container)
}
