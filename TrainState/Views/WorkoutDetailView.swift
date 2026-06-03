import SwiftUI
import SwiftData
import CoreLocation
import HealthKit

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSubcategory.name) private var allSubcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Query(sort: \Workout.startDate, order: .reverse) private var allWorkouts: [Workout]
    @AppStorage("measurementSystem") private var measurementSystemRaw = MeasurementSystem.metric.rawValue
    @Bindable var workout: Workout
    @AppStorage("restTimerEnabled") private var restTimerEnabled = false
    @AppStorage("restTimerDurationSeconds") private var restTimerDurationSeconds = 90
    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var exerciseDraftsByID: [UUID: ExerciseLogEntry] = [:]
    @State private var restSecondsRemaining: Int?
    @Query(sort: \StrengthWorkoutTemplate.updatedAt, order: .reverse) private var strengthTemplates: [StrengthWorkoutTemplate]
    @State private var showingDeleteConfirmation = false
    @State private var showingRouteMapSheet = false
    @State private var showingSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var showingExercisePicker = false
    @State private var showingExerciseEditor = false
    @State private var showingCategoryAssignment = false
    @State private var showingExerciseReorder = false
    @State private var editingExerciseID: UUID?
    @State private var exerciseDraftEntry = ExerciseLogEntry()
    @State private var originalExerciseDraftEntry = ExerciseLogEntry()
    @State private var exerciseInsightTarget: ExerciseInsightTarget?
    @State private var pendingExerciseSaveTask: Task<Void, Never>?
    @State private var pendingCategoryAssignmentSaveTask: Task<Void, Never>?
    @State private var selectedCategoriesForAssignment: [WorkoutCategory] = []
    @State private var selectedSubcategoriesForAssignment: [WorkoutSubcategory] = []
    @State private var showingCategoriesManagement = false
    @State private var activeRatingTarget: RatingPickerTarget?

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

            if !(workout.subcategories ?? []).isEmpty {
                SubcategoryRatingSection(
                    title: "Subcategory Ratings",
                    subcategories: (workout.subcategories ?? []).sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    },
                    ratingsBySubcategoryID: subcategoryRatingsBinding,
                    tintColor: workout.primaryWorkoutTintColor,
                    showsBodyPartIcons: (workout.appleWorkoutActivityType?.mappedWorkoutType ?? workout.type) == .strength,
                    onEditRating: { subcategory in
                        activeRatingTarget = RatingPickerTarget(
                            context: "subcategory",
                            sourceID: subcategory.id,
                            title: subcategory.name,
                            subtitle: "Rate how hard this subcategory was hit from 1 to 10.",
                            clearTitle: "Clear"
                        )
                    }
                )
            }

            Section {
                addExercisesButton

                if let exercises = workout.exercises, !exercises.isEmpty {
                    if hasUncategorizedExercises {
                        Text("Categorize exercises for better insights. Tap Exercise on a card to assign a subcategory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Exercises")
            }

            if let exercises = workout.exercises, !exercises.isEmpty {
                ForEach(exercises.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { exercise in
                    Section {
                        ExerciseSessionCard(
                            entry: exerciseDraftBinding(for: exercise),
                            isExpanded: exerciseExpansionBinding(for: exercise.id),
                            subcategoryName: exercise.subcategory?.name,
                            affectedSubcategoryNames: affectedSubcategoryNames(for: exercise),
                            tintColor: workout.primaryWorkoutTintColor,
                            measurementSystem: MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric,
                            restTimerEnabled: restTimerEnabled,
                            restDurationSeconds: restTimerDurationSeconds,
                            onEditMetadata: {
                                openExerciseEditor(for: exercise)
                            },
                            onStartRest: {
                                restSecondsRemaining = max(restTimerDurationSeconds, 15)
                            },
                            onEditEffortScore: {
                                activeRatingTarget = RatingPickerTarget(
                                    context: "exercise",
                                    sourceID: exercise.id,
                                    title: exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Toughness" : exercise.name,
                                    subtitle: "Rate how tough this exercise felt from 1 to 10.",
                                    clearTitle: "Clear"
                                )
                            },
                            onViewExercisePage: {
                                exerciseInsightTarget = ExerciseInsightTarget(
                                    id: exercise.id,
                                    exerciseName: exercise.name,
                                    subcategoryID: exercise.subcategory?.id
                                )
                            }
                        )
                    }
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
        .listSectionSpacing(.custom(10))
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if (workout.exercises ?? []).count > 1 {
                    Button {
                        showingExerciseReorder = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Reorder Exercises")
                }

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
                },
                scope: .metadataOnly
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
                CategoriesManagementView(
                    workoutType: workout.type,
                    appleWorkoutActivityType: workout.appleWorkoutActivityType
                )
            }
        }
        .sheet(isPresented: $showingExerciseReorder) {
            ExerciseReorderSheet(
                exercises: workout.exercises ?? [],
                onMove: moveExercises
            )
        }
        .sheet(item: $activeRatingTarget) { target in
            if target.context == "exercise" {
                RatingPickerSheet(
                    title: target.title,
                    subtitle: target.subtitle,
                    clearTitle: target.clearTitle,
                    tintColor: workout.primaryWorkoutTintColor,
                    rating: exerciseEffortScoreBinding(for: target.sourceID)
                )
                .presentationDetents([.fraction(0.58), .medium])
                .presentationDragIndicator(.visible)
            } else if target.context == "subcategory" {
                RatingPickerSheet(
                    title: target.title,
                    subtitle: target.subtitle,
                    clearTitle: target.clearTitle,
                    tintColor: workout.primaryWorkoutTintColor,
                    rating: subcategoryRatingBinding(for: target.sourceID)
                )
                .presentationDetents([.fraction(0.58), .medium])
                .presentationDragIndicator(.visible)
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
        .onAppear {
            syncExerciseDraftsFromWorkout()
        }
        .onChange(of: workout.exercises?.map(\.id)) { _, _ in
            syncExerciseDraftsFromWorkout()
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
        let currentRatings = WorkoutSubcategoryRatingStore.ratingsBySubcategoryID(for: workout)
        workout.categories = selectedCategoriesForAssignment
        workout.subcategories = selectedSubcategoriesForAssignment
        WorkoutSubcategoryRatingStore.replaceRatings(
            on: workout,
            with: currentRatings,
            subcategories: selectedSubcategoriesForAssignment,
            modelContext: modelContext
        )
        try? modelContext.save()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var orderedExercises = (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        orderedExercises.move(fromOffsets: source, toOffset: destination)

        for (index, exercise) in orderedExercises.enumerated() {
            exercise.orderIndex = index
        }

        try? modelContext.save()
    }

    private var subcategoryRatingsBinding: Binding<[UUID: Int]> {
        Binding(
            get: {
                WorkoutSubcategoryRatingStore.ratingsBySubcategoryID(for: workout)
            },
            set: { newRatings in
                WorkoutSubcategoryRatingStore.replaceRatings(
                    on: workout,
                    with: newRatings,
                    subcategories: workout.subcategories ?? [],
                    modelContext: modelContext
                )
                try? modelContext.save()
            }
        )
    }

    private func subcategoryRatingBinding(for subcategoryID: UUID) -> Binding<Int?> {
        Binding(
            get: {
                WorkoutSubcategoryRatingStore.ratingsBySubcategoryID(for: workout)[subcategoryID]
            },
            set: { newValue in
                var ratings = WorkoutSubcategoryRatingStore.ratingsBySubcategoryID(for: workout)
                ratings[subcategoryID] = newValue.map { min(max($0, 1), 10) }
                WorkoutSubcategoryRatingStore.replaceRatings(
                    on: workout,
                    with: ratings,
                    subcategories: workout.subcategories ?? [],
                    modelContext: modelContext
                )
                try? modelContext.save()
            }
        )
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
        syncWorkoutClassification(for: classificationSubcategories(for: option))
        let previousMatch = (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .last { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(option.name) == .orderedSame }

        let exercise = WorkoutExercise(
            name: option.name,
            sets: previousMatch?.sets,
            reps: previousMatch?.reps,
            weight: previousMatch?.weight,
            effortScore: previousMatch?.effortScore,
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
        exerciseDraftsByID[exercise.id] = exerciseLogEntry(from: exercise)
        expandedExerciseIDs.insert(exercise.id)
        try? modelContext.save()
    }

    private func addCustomExerciseToWorkout(name: String, subcategoryID: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveExerciseTemplateIfNeeded(name: trimmed, subcategoryID: subcategoryID)
        addExerciseToWorkout(from: ExerciseQuickAddOption(name: trimmed, subcategoryID: subcategoryID))
    }

    private func saveExerciseTemplateIfNeeded(name: String, subcategoryID: UUID) {
        guard let subcategory = allSubcategories.first(where: { $0.id == subcategoryID }) else { return }
        let exists = exerciseTemplates.contains {
            $0.subcategory?.id == subcategoryID &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame
        }
        guard !exists else { return }

        let order = exerciseTemplates.filter { $0.subcategory?.id == subcategoryID }.count
        modelContext.insert(SubcategoryExercise(name: name, subcategory: subcategory, orderIndex: order))
        try? modelContext.save()
    }

    private func classificationSubcategories(for option: ExerciseQuickAddOption) -> [WorkoutSubcategory] {
        guard let primarySubcategory = allSubcategories.first(where: { $0.id == option.subcategoryID }) else {
            return []
        }

        guard let primaryWorkoutType = primarySubcategory.category?.resolvedWorkoutType else {
            return [primarySubcategory]
        }

        let template = exerciseTemplates.first {
            $0.subcategory?.id == option.subcategoryID &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(option.name) == .orderedSame
        }
        let secondarySubcategories = (template?.secondarySubcategoryIDs ?? []).compactMap { id -> WorkoutSubcategory? in
            guard let secondarySubcategory = allSubcategories.first(where: { $0.id == id }),
                  secondarySubcategory.id != primarySubcategory.id,
                  secondarySubcategory.category?.resolvedWorkoutType == primaryWorkoutType else {
                return nil
            }
            return secondarySubcategory
        }

        return [primarySubcategory] + secondarySubcategories
    }

    private func affectedSubcategoryNames(for exercise: WorkoutExercise) -> [String] {
        let entry = exerciseDraftsByID[exercise.id] ?? exerciseLogEntry(from: exercise)
        return affectedSubcategoryNames(for: entry)
    }

    private func affectedSubcategoryNames(for entry: ExerciseLogEntry) -> [String] {
        guard let primarySubcategoryID = entry.subcategoryID,
              let primarySubcategory = allSubcategories.first(where: { $0.id == primarySubcategoryID }),
              let primaryWorkoutType = primarySubcategory.category?.resolvedWorkoutType else {
            return []
        }

        let trimmedName = entry.trimmedName
        guard !trimmedName.isEmpty,
              let template = exerciseTemplates.first(where: {
                  $0.subcategory?.id == primarySubcategoryID &&
                  $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedName) == .orderedSame
              }) else {
            return []
        }

        return template.secondarySubcategoryIDs.compactMap { id -> String? in
            guard let subcategory = allSubcategories.first(where: { $0.id == id }),
                  subcategory.id != primarySubcategory.id,
                  subcategory.category?.resolvedWorkoutType == primaryWorkoutType else {
                return nil
            }
            return subcategory.name
        }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func syncWorkoutClassification(for subcategories: [WorkoutSubcategory]) {
        guard !subcategories.isEmpty else { return }

        for subcategory in subcategories {
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
    }

    private func openExerciseEditor(for exercise: WorkoutExercise) {
        pendingExerciseSaveTask?.cancel()
        pendingExerciseSaveTask = nil
        editingExerciseID = exercise.id
        let draft = exerciseDraftsByID[exercise.id] ?? exerciseLogEntry(from: exercise)
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

        applyExerciseLogEntry(exerciseDraftEntry, to: exercise)
        exerciseDraftsByID[exercise.id] = exerciseDraftEntry
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

    private var hasUncategorizedExercises: Bool {
        (workout.exercises ?? []).contains { $0.subcategory == nil && !$0.name.isEmpty }
    }

    private func exerciseLogEntry(from exercise: WorkoutExercise) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: exercise.id,
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            weight: exercise.weight,
            effortScore: exercise.effortScore,
            subcategoryID: exercise.subcategory?.id,
            setEntries: ExerciseSetPlanSerializer.setEntries(from: exercise)
        )
    }

    private func applyExerciseLogEntry(_ entry: ExerciseLogEntry, to exercise: WorkoutExercise) {
        exercise.name = entry.trimmedName
        exercise.sets = entry.effectiveSetCount
        exercise.reps = entry.effectiveReps
        exercise.weight = entry.effectiveWeight
        exercise.effortScore = entry.effortScore
        exercise.notes = ExerciseSetPlanSerializer.notes(from: entry.setEntries)
        exercise.setPlanJSON = ExerciseSetPlanSerializer.encodeJSON(entry.setEntries)
        exercise.subcategory = allSubcategories.first { $0.id == entry.subcategoryID }
    }

    private func exerciseExpansionBinding(for exerciseID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedExerciseIDs.contains(exerciseID) },
            set: { isExpanded in
                if isExpanded {
                    expandedExerciseIDs.insert(exerciseID)
                } else {
                    expandedExerciseIDs.remove(exerciseID)
                }
            }
        )
    }

    private func exerciseDraftBinding(for exercise: WorkoutExercise) -> Binding<ExerciseLogEntry> {
        Binding(
            get: {
                if let draft = exerciseDraftsByID[exercise.id] {
                    return draft
                }
                return exerciseLogEntry(from: exercise)
            },
            set: { newValue in
                exerciseDraftsByID[exercise.id] = newValue
                scheduleExerciseDraftPersistence(for: exercise.id)
            }
        )
    }

    private func exerciseEffortScoreBinding(for exerciseID: UUID) -> Binding<Int?> {
        Binding(
            get: {
                if let draft = exerciseDraftsByID[exerciseID] {
                    return draft.effortScore
                }
                return workout.exercises?.first { $0.id == exerciseID }?.effortScore
            },
            set: { newValue in
                guard let exercise = workout.exercises?.first(where: { $0.id == exerciseID }) else { return }
                var draft = exerciseDraftsByID[exercise.id] ?? exerciseLogEntry(from: exercise)
                draft.effortScore = newValue.map { min(max($0, 1), 10) }
                exerciseDraftsByID[exercise.id] = draft
                scheduleExerciseDraftPersistence(for: exercise.id)
            }
        )
    }

    private func syncExerciseDraftsFromWorkout() {
        let exercises = (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        var updated = exerciseDraftsByID
        for exercise in exercises {
            if updated[exercise.id] == nil {
                updated[exercise.id] = exerciseLogEntry(from: exercise)
            }
        }
        let validIDs = Set(exercises.map(\.id))
        updated.keys.filter { !validIDs.contains($0) }.forEach { updated.removeValue(forKey: $0) }
        exerciseDraftsByID = updated
    }

    private func scheduleExerciseDraftPersistence(for exerciseID: UUID) {
        pendingExerciseSaveTask?.cancel()
        pendingExerciseSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            persistExerciseDraft(exerciseID: exerciseID)
        }
    }

    private func persistExerciseDraft(exerciseID: UUID) {
        guard let draft = exerciseDraftsByID[exerciseID],
              let exercise = workout.exercises?.first(where: { $0.id == exerciseID }) else {
            return
        }
        applyExerciseLogEntry(draft, to: exercise)
        try? modelContext.save()
    }
}

private struct ExerciseInsightTarget: Identifiable, Hashable {
    let id: UUID
    let exerciseName: String
    let subcategoryID: UUID?
}

private struct ExerciseReorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderedExercises: [WorkoutExercise]
    let onMove: (IndexSet, Int) -> Void

    init(exercises: [WorkoutExercise], onMove: @escaping (IndexSet, Int) -> Void) {
        self._orderedExercises = State(initialValue: exercises.sorted { $0.orderIndex < $1.orderIndex })
        self.onMove = onMove
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedExercises, id: \.id) { exercise in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unnamed Exercise" : exercise.name)
                                .font(.body)

                            if let subcategoryName = exercise.subcategory?.name, !subcategoryName.isEmpty {
                                Text(subcategoryName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: ExerciseIconMapper.icon(for: exercise.name))
                            .foregroundStyle(ExerciseIconMapper.iconColor(for: exercise.name))
                    }
                }
                .onMove { source, destination in
                    orderedExercises.move(fromOffsets: source, toOffset: destination)
                    onMove(source, destination)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
private func makeWorkoutDetailPreviewData() -> (container: ModelContainer, workout: Workout) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, WorkoutExercise.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self, configurations: config)
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
            sets: 0,
            reps: 0,
            weight: 0,
            notes: nil,
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
