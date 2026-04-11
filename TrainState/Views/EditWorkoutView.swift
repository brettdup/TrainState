import SwiftUI
import SwiftData
import HealthKit

struct EditWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSubcategory.name) private var allSubcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Bindable var workout: Workout

    @State private var type: WorkoutType
    @State private var selectedAppleWorkout: AppleWorkoutSelection
    @State private var date: Date
    @State private var durationMinutes: Double
    @State private var distanceKilometers: Double
    @State private var workoutRating: Double?
    @State private var notes: String
    @State private var exerciseEntries: [ExerciseLogEntry]
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var showingAdvancedFields = false
    @State private var lastPersistedSnapshot: EditWorkoutSnapshot
    @State private var showingCategoryAssignment = false
    @State private var selectedCategoriesForAssignment: [WorkoutCategory]
    @State private var selectedSubcategoriesForAssignment: [WorkoutSubcategory]
    @State private var showingCategoriesManagement = false

    private let quickDurations: [Double] = [15, 30, 45, 60, 90, 120]
    private var durationBinding: Binding<Double> {
        Binding(
            get: { durationMinutes },
            set: { durationMinutes = min(max($0, 0), 600) }
        )
    }
    private var distanceBinding: Binding<Double> {
        Binding(
            get: { distanceKilometers },
            set: { distanceKilometers = min(max($0, 0), 200) }
        )
    }
    private var workoutRatingBinding: Binding<Double> {
        Binding(
            get: { workoutRating ?? 5.0 },
            set: { workoutRating = min(max($0, 0), 10) }
        )
    }
    private var showsDistance: Bool {
        [.running, .cycling, .swimming].contains(type)
    }
    private var appleWorkoutActivityType: HKWorkoutActivityType { selectedAppleWorkout.activityType }
    private var appleWorkoutLocationType: HKWorkoutSessionLocationType? { selectedAppleWorkout.locationType }
    private var appleWorkoutActivityOptions: [AppleWorkoutSelection] { WorkoutType.other.appleWorkoutActivityOptions }
    private var isImportedFromHealthKit: Bool {
        workout.hkUUID != nil
    }
    private var availableExerciseSubcategories: [WorkoutSubcategory] {
        allSubcategories.filter { subcategory in
            guard let category = subcategory.category else { return false }
            return category.matches(
                appleWorkoutActivityType: appleWorkoutActivityType,
                fallbackWorkoutType: type
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

    init(workout: Workout) {
        self.workout = workout
        let snapshot = EditWorkoutSnapshot(workout: workout)
        _type = State(initialValue: workout.type)
        _selectedAppleWorkout = State(initialValue: AppleWorkoutSelection.normalized(
            activityType: workout.appleWorkoutActivityType ?? workout.type.defaultAppleWorkoutActivityType,
            locationType: workout.appleWorkoutLocationType
        ))
        _date = State(initialValue: workout.startDate)
        _durationMinutes = State(initialValue: workout.duration / 60)
        _distanceKilometers = State(initialValue: workout.distance ?? 0)
        _workoutRating = State(initialValue: workout.rating)
        _notes = State(initialValue: workout.notes ?? "")
        _exerciseEntries = State(initialValue: (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                ExerciseLogEntry(
                    name: $0.name,
                    sets: $0.sets,
                    reps: $0.reps,
                    weight: $0.weight,
                    subcategoryID: $0.subcategory?.id,
                    setEntries: Self.parseSetEntries(from: $0.notes)
                )
            })
        _lastPersistedSnapshot = State(initialValue: snapshot)
        _selectedCategoriesForAssignment = State(initialValue: workout.categories ?? [])
        _selectedSubcategoriesForAssignment = State(initialValue: workout.subcategories ?? [])
    }

    var body: some View {
        Form {
            appleWorkoutTypeCard
            dateCard
            durationCard
            if showsDistance { distanceCard }
            if type == .strength {
                strengthManagementSection
            }
            exercisesCard
            advancedSectionCard
            if showingAdvancedFields {
                ratingCard
                notesCard
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $activeExerciseSelection) { selection in
            if let index = exerciseEntries.firstIndex(where: { $0.id == selection.id }) {
                ExerciseEditorSheetView(
                    entry: $exerciseEntries[index],
                    availableSubcategories: availableExerciseSubcategories,
                    availableOptions: quickAddOptions,
                    onDelete: {
                        exerciseEntries.removeAll { $0.id == selection.id }
                    }
                )
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingCategoryAssignment) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategoriesForAssignment,
                selectedSubcategories: $selectedSubcategoriesForAssignment,
                workoutType: type,
                appleWorkoutActivityType: appleWorkoutActivityType,
                lockedSubcategoryIDs: Set(exerciseEntries.compactMap(\.subcategoryID))
            )
        }
        .sheet(isPresented: $showingCategoriesManagement) {
            NavigationStack {
                CategoriesManagementView()
            }
        }
        .onChange(of: selectedAppleWorkout) { _, newSelection in
            type = newSelection.activityType.mappedWorkoutType
            let allowedIDs = Set(availableExerciseSubcategories.map(\.id))
            exerciseEntries = exerciseEntries.map {
                var entry = $0
                if let id = entry.subcategoryID, !allowedIDs.contains(id) {
                    entry.subcategoryID = nil
                }
                return entry
            }
            if type == .strength && exerciseEntries.isEmpty {
                exerciseEntries = [defaultExerciseEntry()]
            }
        }
        .onChange(of: activeExerciseSelection) { _, newValue in
            // When leaving the editor page, clean up any fully empty exercises.
            // Do this on the next runloop tick so we don't mutate the array
            // while SwiftUI is still holding index-based bindings into it.
            if newValue == nil {
                DispatchQueue.main.async {
                    exerciseEntries.removeAll { $0.isEmpty }
                }
            }
        }
        .onChange(of: showingCategoryAssignment) { _, isPresented in
            if !isPresented {
                workout.categories = selectedCategoriesForAssignment
                workout.subcategories = selectedSubcategoriesForAssignment
                persistChangesIfNeeded()
            }
        }
        .task(id: currentSnapshot) {
            await autosaveIfNeeded()
        }
        .onDisappear {
            persistChangesIfNeeded()
        }
    }

    private var appleWorkoutTypeCard: some View {
        Section("Apple Workout Type") {
            Picker("Apple Workout Type", selection: $selectedAppleWorkout) {
                ForEach(appleWorkoutActivityOptions) { selection in
                    Text(selection.displayName).tag(selection)
                }
            }
        }
    }

    private var dateCard: some View {
        Section("Date & Time") {
            DatePicker("Date", selection: $date)
                .datePickerStyle(.compact)
        }
    }

    private var advancedSectionCard: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingAdvancedFields.toggle()
                }
            } label: {
                HStack {
                    Text("More details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showingAdvancedFields ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var durationCard: some View {
        Section("Duration") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                ForEach(quickDurations, id: \.self) { mins in
                    Button {
                        durationMinutes = mins
                    } label: {
                        Text("\(Int(mins)) min")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(durationMinutes == mins ? type.tintColor.opacity(0.2) : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(durationMinutes == mins ? type.tintColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Minutes", value: durationBinding, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
        }
    }

    private var distanceCard: some View {
        Section("Distance") {
            TextField("Kilometers", value: distanceBinding, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
        }
    }

    private var ratingCard: some View {
        Section("Workout Rating") {
            if isImportedFromHealthKit {
                if let workoutRating {
                    Text(String(format: "%.1f / 10", workoutRating))
                        .font(.title3.weight(.semibold))
                } else {
                    Text("No rating available from Apple Health.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Imported workouts read rating from Apple Health.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if workoutRating == nil {
                Button {
                    workoutRating = 5.0
                } label: {
                    Label("Add Rating", systemImage: "star")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(type.tintColor.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(format: "%.1f / 10", workoutRating ?? 0))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button("Clear") {
                            workoutRating = nil
                        }
                        .font(.caption.weight(.semibold))
                    }

                    Slider(value: workoutRatingBinding, in: 0...10, step: 0.5)
                        .tint(type.tintColor)
                }
            }
        }
    }

    private var exercisesCard: some View {
        WorkoutExerciseSectionView(
            entries: $exerciseEntries,
            tintColor: type.tintColor,
            availableSubcategories: availableExerciseSubcategories,
            quickAddOptions: quickAddOptions,
            allowsReordering: true,
            onTap: { entry in
                activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
            }
        )
    }

    private var notesCard: some View {
        Section("Notes") {
            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var strengthManagementSection: some View {
        WorkoutStructureSection(
            title: "Strength Setup",
            primaryActionTitle: "Assign Categories",
            primaryActionSubtitle: categoryAssignmentSummary,
            primaryAction: {
                selectedCategoriesForAssignment = workout.categories ?? []
                selectedSubcategoriesForAssignment = workout.subcategories ?? []
                showingCategoryAssignment = true
            },
            secondaryActionTitle: "Manage Exercise Library",
            secondaryActionSubtitle: "Edit categories, subcategories, and exercise templates",
            secondaryAction: { showingCategoriesManagement = true },
            categoryItems: selectedCategorySummaryItems,
            subcategoryItems: selectedSubcategorySummaryItems,
            emptyStateText: "No categories assigned."
        )
    }

    private var currentSnapshot: EditWorkoutSnapshot {
        EditWorkoutSnapshot(
            type: type,
            appleWorkoutActivityTypeRawValue: Int(appleWorkoutActivityType.rawValue),
            appleWorkoutLocationTypeRawValue: appleWorkoutLocationType?.rawValue ?? HKWorkoutSessionLocationType.unknown.rawValue,
            date: date,
            durationMinutes: durationMinutes,
            distanceKilometers: distanceKilometers,
            workoutRating: workoutRating,
            notes: notes,
            categoryIDs: selectedCategoriesForAssignment.map(\.id),
            subcategoryIDs: selectedSubcategoriesForAssignment.map(\.id),
            exerciseSignatures: exerciseEntries.map(EditWorkoutSnapshot.ExerciseSignature.init)
        )
    }

    private var categoryAssignmentSummary: String {
        let categoryCount = selectedCategoriesForAssignment.count
        let subcategoryCount = selectedSubcategoriesForAssignment.count
        if categoryCount == 0 && subcategoryCount == 0 {
            return "No categories assigned"
        }
        return "\(categoryCount) categories • \(subcategoryCount) subcategories"
    }

    private var selectedCategorySummaryItems: [WorkoutStructureSummaryItem] {
        selectedCategoriesForAssignment.map {
            WorkoutStructureSummaryItem(
                title: $0.name,
                tint: Color(hex: $0.color) ?? type.tintColor,
                symbol: "folder.fill"
            )
        }
    }

    private var selectedSubcategorySummaryItems: [WorkoutStructureSummaryItem] {
        selectedSubcategoriesForAssignment.map {
            WorkoutStructureSummaryItem(
                title: $0.name,
                tint: $0.category.flatMap { Color(hex: $0.color) } ?? type.tintColor,
                symbol: "tag.fill"
            )
        }
    }

    private func defaultExerciseEntry() -> ExerciseLogEntry {
        guard let firstSubcategory = availableExerciseSubcategories.first else { return ExerciseLogEntry() }
        let templates = quickAddOptions.filter { $0.subcategoryID == firstSubcategory.id }.map(\.name)
        return ExerciseLogEntry(
            name: templates.first ?? "",
            subcategoryID: firstSubcategory.id
        )
    }

    private func exerciseSummary(for entry: ExerciseLogEntry) -> String? {
        let setsText = entry.sets.map { "\($0)x" }
        let repsText = entry.reps.map { "\($0)" }
        let weightText: String? = {
            guard let w = entry.weight, w > 0 else { return nil }
            return String(format: "%.1f kg", w)
        }()

        let primary = [setsText, repsText].compactMap { $0 }.joined(separator: " ")
        let withWeight: String
        if let weightText {
            withWeight = primary.isEmpty ? weightText : "\(primary) · \(weightText)"
        } else {
            withWeight = primary
        }

        return withWeight.isEmpty ? nil : withWeight
    }

    private func persistExerciseTemplates(from entries: [ExerciseLogEntry]) {
        var insertedKeys: Set<String> = []
        for entry in entries {
            let name = entry.trimmedName
            guard !name.isEmpty, let subcategoryID = entry.subcategoryID else { continue }

            let key = "\(subcategoryID.uuidString)|\(name.lowercased())"
            guard !insertedKeys.contains(key) else { continue }

            let exists = exerciseTemplates.contains {
                $0.subcategory?.id == subcategoryID &&
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }
            guard !exists,
                  let subcategory = allSubcategories.first(where: { $0.id == subcategoryID }) else { continue }

            let order = exerciseTemplates.filter { $0.subcategory?.id == subcategoryID }.count
            let template = SubcategoryExercise(name: name, subcategory: subcategory, orderIndex: order)
            modelContext.insert(template)
            insertedKeys.insert(key)
        }
        if modelContext.hasChanges {
            try? modelContext.save()
        }
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

    @MainActor
    private func autosaveIfNeeded() async {
        let snapshot = currentSnapshot
        guard snapshot != lastPersistedSnapshot else { return }

        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        persistChangesIfNeeded()
    }

    @MainActor
    private func persistChangesIfNeeded() {
        let snapshot = currentSnapshot
        guard snapshot != lastPersistedSnapshot else { return }

        persistExerciseTemplates(from: exerciseEntries)

        workout.type = type
        workout.appleWorkoutActivityType = appleWorkoutActivityType
        workout.appleWorkoutLocationType = appleWorkoutLocationType
        workout.startDate = date
        workout.duration = durationMinutes * 60
        workout.distance = showsDistance && distanceKilometers > 0 ? distanceKilometers : nil
        if !isImportedFromHealthKit {
            workout.rating = workoutRating
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        workout.categories = selectedCategoriesForAssignment
        workout.subcategories = selectedSubcategoriesForAssignment
        (workout.exercises ?? []).forEach { modelContext.delete($0) }
        workout.exercises = exerciseEntries.enumerated().compactMap { index, entry in
            let name = entry.trimmedName
            guard !name.isEmpty else { return nil }
            let linkedSubcategory = allSubcategories.first { $0.id == entry.subcategoryID }
            return WorkoutExercise(
                name: name,
                sets: entry.sets,
                reps: entry.reps,
                weight: entry.weight,
                notes: exerciseNotes(for: entry),
                orderIndex: index,
                subcategory: linkedSubcategory
            )
        }

        do {
            try modelContext.save()
            lastPersistedSnapshot = currentSnapshot
        } catch {
            return
        }
    }
}

private struct EditWorkoutSnapshot: Equatable {
    struct ExerciseSignature: Equatable {
        let name: String
        let sets: Int?
        let reps: Int?
        let weight: Double?
        let subcategoryID: UUID?
        let setNotes: String?

        init(_ entry: ExerciseLogEntry) {
            self.name = entry.trimmedName
            self.sets = entry.sets
            self.reps = entry.reps
            self.weight = entry.weight
            self.subcategoryID = entry.subcategoryID
            self.setNotes = entry.setSummaryLines.isEmpty ? nil : entry.setSummaryLines.joined(separator: "\n")
        }

        init(name: String, sets: Int?, reps: Int?, weight: Double?, subcategoryID: UUID?, setNotes: String?) {
            self.name = name
            self.sets = sets
            self.reps = reps
            self.weight = weight
            self.subcategoryID = subcategoryID
            self.setNotes = setNotes
        }
    }

    let type: WorkoutType
    let appleWorkoutActivityTypeRawValue: Int
    let appleWorkoutLocationTypeRawValue: Int
    let date: Date
    let durationMinutes: Double
    let distanceKilometers: Double
    let workoutRating: Double?
    let notes: String
    let categoryIDs: [UUID]
    let subcategoryIDs: [UUID]
    let exerciseSignatures: [ExerciseSignature]

    init(workout: Workout) {
        self.type = workout.type
        self.appleWorkoutActivityTypeRawValue = workout.hkActivityTypeRaw ?? Int(workout.type.defaultAppleWorkoutActivityType.rawValue)
        self.appleWorkoutLocationTypeRawValue = workout.hkLocationTypeRaw ?? HKWorkoutSessionLocationType.unknown.rawValue
        self.date = workout.startDate
        self.durationMinutes = workout.duration / 60
        self.distanceKilometers = workout.distance ?? 0
        self.workoutRating = workout.rating
        self.notes = workout.notes ?? ""
        self.categoryIDs = (workout.categories ?? []).map(\.id)
        self.subcategoryIDs = (workout.subcategories ?? []).map(\.id)
        self.exerciseSignatures = (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                ExerciseSignature(
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    sets: $0.sets,
                    reps: $0.reps,
                    weight: $0.weight,
                    subcategoryID: $0.subcategory?.id,
                    setNotes: $0.notes
                )
            }
    }

    init(
        type: WorkoutType,
        appleWorkoutActivityTypeRawValue: Int,
        appleWorkoutLocationTypeRawValue: Int,
        date: Date,
        durationMinutes: Double,
        distanceKilometers: Double,
        workoutRating: Double?,
        notes: String,
        categoryIDs: [UUID],
        subcategoryIDs: [UUID],
        exerciseSignatures: [ExerciseSignature]
    ) {
        self.type = type
        self.appleWorkoutActivityTypeRawValue = appleWorkoutActivityTypeRawValue
        self.appleWorkoutLocationTypeRawValue = appleWorkoutLocationTypeRawValue
        self.date = date
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.workoutRating = workoutRating
        self.notes = notes
        self.categoryIDs = categoryIDs
        self.subcategoryIDs = subcategoryIDs
        self.exerciseSignatures = exerciseSignatures
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: Workout.self,
        WorkoutCategory.self,
        WorkoutSubcategory.self,
        WorkoutExercise.self,
        SubcategoryExercise.self,
        configurations: config
    )
    let context = container.mainContext

    let strength = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
    context.insert(strength)
    let chest = WorkoutSubcategory(name: "Chest", category: strength)
    context.insert(chest)
    let back = WorkoutSubcategory(name: "Back", category: strength)
    context.insert(back)

    context.insert(SubcategoryExercise(name: "Bench Press", subcategory: chest, orderIndex: 0))
    context.insert(SubcategoryExercise(name: "Incline Press", subcategory: chest, orderIndex: 1))
    context.insert(SubcategoryExercise(name: "Barbell Row", subcategory: back, orderIndex: 0))

    let workout = Workout(
        type: .strength,
        startDate: .now,
        duration: 3600,
        distance: nil,
        categories: [strength],
        subcategories: [chest]
    )
    workout.notes = "Focus on controlled reps."
    workout.exercises = [
        WorkoutExercise(name: "Bench Press", sets: 4, reps: 8, weight: 80, orderIndex: 0, subcategory: chest)
    ]
    context.insert(workout)

    return NavigationStack {
        EditWorkoutView(workout: workout)
    }
    .modelContainer(container)
}
