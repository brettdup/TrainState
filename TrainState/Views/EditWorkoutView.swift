import SwiftUI
import SwiftData

struct EditWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSubcategory.name) private var allSubcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Bindable var workout: Workout

    @State private var type: WorkoutType
    @State private var date: Date
    @State private var durationMinutes: Double
    @State private var distanceKilometers: Double
    @State private var workoutRating: Double?
    @State private var notes: String
    @State private var selectedCategories: [WorkoutCategory]
    @State private var selectedSubcategories: [WorkoutSubcategory]
    @State private var exerciseEntries: [ExerciseLogEntry]
    @State private var showingCategoryPicker = false
    @State private var showingExercisePicker = false
    @State private var showingUnifiedPicker = false
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var isSaving = false
    @State private var showingExerciseLinkAlert = false
    @State private var showingAdvancedFields = false
    @State private var showingDiscardChangesAlert = false
    private let initialSnapshot: EditWorkoutSnapshot

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
    private var isImportedFromHealthKit: Bool {
        workout.hkUUID != nil
    }
    private var availableExerciseSubcategories: [WorkoutSubcategory] {
        if !selectedSubcategories.isEmpty { return selectedSubcategories }
        return allSubcategories.filter { $0.category?.workoutType == type || $0.category?.workoutType == nil }
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
        self.initialSnapshot = EditWorkoutSnapshot(workout: workout)
        _type = State(initialValue: workout.type)
        _date = State(initialValue: workout.startDate)
        _durationMinutes = State(initialValue: workout.duration / 60)
        _distanceKilometers = State(initialValue: workout.distance ?? 0)
        _workoutRating = State(initialValue: workout.rating)
        _notes = State(initialValue: workout.notes ?? "")
        _selectedCategories = State(initialValue: workout.categories ?? [])
        _selectedSubcategories = State(initialValue: workout.subcategories ?? [])
        _exerciseEntries = State(initialValue: (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                ExerciseLogEntry(
                    name: $0.name,
                    sets: $0.sets,
                    reps: $0.reps,
                    weight: $0.weight,
                    subcategoryID: $0.subcategory?.id
                )
            })
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.04 : 0.015),
                    Color(.systemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    typeCard
                    dateCard
                    durationCard
                    if showsDistance { distanceCard }
                    categoriesCard
                    exercisesCard
                    advancedSectionCard
                    if showingAdvancedFields {
                        ratingCard
                        notesCard
                    }
                    saveButton
                }
                .glassEffectContainer(spacing: 16)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { handleCancelTapped() }
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategories,
                selectedSubcategories: $selectedSubcategories,
                workoutType: type
            )
        }
        .sheet(isPresented: $showingExercisePicker) {
            UnifiedExercisePickerView(
                subcategories: availableExerciseSubcategories,
                exerciseOptions: quickAddOptions,
                existingExerciseNames: Set(exerciseEntries.map { $0.trimmedName.lowercased() }),
                onSelect: { selected in
                    addExercises(from: selected)
                },
                onCreateCustom: { name, subcategoryID in
                    let newEntry = ExerciseLogEntry(
                        name: name,
                        sets: nil,
                        reps: nil,
                        weight: nil,
                        subcategoryID: subcategoryID
                    )
                    exerciseEntries.append(newEntry)
                    ensureSelectionForSubcategoryID(subcategoryID)
                },
                tintColor: type.tintColor
            )
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
        .alert("Link Exercises to Subcategories", isPresented: $showingExerciseLinkAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Each exercise must be linked to a subcategory before saving.")
        }
        .alert("Discard changes?", isPresented: $showingDiscardChangesAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("You have unsaved changes.")
        }
        .onChange(of: type) { _, _ in
            selectedCategories.removeAll()
            selectedSubcategories.removeAll()
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
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Type")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(WorkoutType.allCases) { workoutType in
                    EditTypeOptionButton(
                        type: workoutType,
                        isSelected: type == workoutType
                    ) {
                        type = workoutType
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date & Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            DatePicker("", selection: $date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var advancedSectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duration")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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

            HStack(spacing: 8) {
                TextField(
                    "Duration",
                    value: durationBinding,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))

                Text("min")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var distanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Distance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(
                    "Distance",
                    value: distanceBinding,
                    format: .number.precision(.fractionLength(0...3))
                )
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))

                Text("km")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                showingCategoryPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(type.tintColor)
                    Text(categoriesSummary)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Rating")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !exerciseEntries.isEmpty {
                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Add exercises button
            Button {
                showingExercisePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(type.tintColor)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(type.tintColor.opacity(0.12))
                )
            }
            .buttonStyle(.plain)

            if exerciseEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No exercises yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap \"Add Exercises\" to search and select from your library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ReorderableExerciseList(
                    entries: $exerciseEntries,
                    colorScheme: colorScheme,
                    onTap: { entry in
                        activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
                    }
                )
            }
            Button {
                addAndEditNewExercise()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                    Text("Add custom exercise")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.72), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 5, x: 0, y: 2)
        )
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var saveButton: some View {
        Button {
            guard !isSaving else { return }
            guard !hasUnlinkedExercises(exerciseEntries) else {
                showingExerciseLinkAlert = true
                return
            }
            // Auto-include any categories/subcategories referenced by exercises.
            syncSelectionFromExercises()
            isSaving = true
            persistExerciseTemplates(from: exerciseEntries)

            workout.type = type
            workout.startDate = date
            workout.duration = durationMinutes * 60
            workout.distance = showsDistance && distanceKilometers > 0 ? distanceKilometers : nil
            if !isImportedFromHealthKit {
                workout.rating = workoutRating
            }
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            workout.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            workout.categories = selectedCategories
            workout.subcategories = selectedSubcategories
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
                    orderIndex: index,
                    subcategory: linkedSubcategory
                )
            }

            do {
                try modelContext.save()
                dismiss()
            } catch {
                isSaving = false
            }
        } label: {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                }
                Text(isSaving ? "Saving..." : "Save Changes")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(type.tintColor)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private var categoriesSummary: String {
        var parts: [String] = []
        if !selectedCategories.isEmpty {
            parts.append(selectedCategories.map(\.name).joined(separator: ", "))
        }
        if !selectedSubcategories.isEmpty {
            parts.append(selectedSubcategories.map(\.name).joined(separator: ", "))
        }
        return parts.isEmpty ? "Select Categories" : parts.joined(separator: " · ")
    }

    private var hasUnsavedChanges: Bool {
        currentSnapshot != initialSnapshot
    }

    private var currentSnapshot: EditWorkoutSnapshot {
        EditWorkoutSnapshot(
            type: type,
            date: date,
            durationMinutes: durationMinutes,
            distanceKilometers: distanceKilometers,
            workoutRating: workoutRating,
            notes: notes,
            selectedCategoryIDs: selectedCategories.map(\.id),
            selectedSubcategoryIDs: selectedSubcategories.map(\.id),
            exerciseSignatures: exerciseEntries.map(EditWorkoutSnapshot.ExerciseSignature.init)
        )
    }

    private func handleCancelTapped() {
        if hasUnsavedChanges {
            showingDiscardChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func hasUnlinkedExercises(_ entries: [ExerciseLogEntry]) -> Bool {
        entries.contains { !$0.trimmedName.isEmpty && $0.subcategoryID == nil }
    }

    private func addAndEditNewExercise() {
        // Start a fully new, blank exercise entry (no template-prefilled name),
        // but link to the first available subcategory when possible so it can be saved
        // and auto-associate categories/subcategories with the workout.
        let initialSubcategoryID = availableExerciseSubcategories.first?.id
        let newEntry = ExerciseLogEntry(
            name: "",
            sets: nil,
            reps: nil,
            weight: nil,
            subcategoryID: initialSubcategoryID
        )
        exerciseEntries.append(newEntry)
        ensureSelectionForSubcategoryID(initialSubcategoryID)
        activeExerciseSelection = ExerciseEditorSelection(id: newEntry.id)
    }

    private func addExercise(from option: ExerciseQuickAddOption) {
        let newEntry = ExerciseLogEntry(
            name: option.name,
            sets: nil,
            reps: nil,
            weight: nil,
            subcategoryID: option.subcategoryID
        )
        exerciseEntries.append(newEntry)
        ensureSelectionForSubcategoryID(option.subcategoryID)
    }

    private func addExercises(from options: [ExerciseQuickAddOption]) {
        for option in options {
            addExercise(from: option)
        }
    }

    /// Ensure that the workout's selected categories/subcategories include anything
    /// referenced by exercise entries, so selection stays in sync with actual content.
    private func syncSelectionFromExercises() {
        for entry in exerciseEntries {
            ensureSelectionForSubcategoryID(entry.subcategoryID)
        }
    }

    private func ensureSelectionForSubcategoryID(_ id: UUID?) {
        guard let id,
              let subcategory = allSubcategories.first(where: { $0.id == id }) else { return }

        if !selectedSubcategories.contains(where: { $0.id == subcategory.id }) {
            selectedSubcategories.append(subcategory)
        }

        if let category = subcategory.category,
           !selectedCategories.contains(where: { $0.id == category.id }) {
            selectedCategories.append(category)
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
}

private struct EditWorkoutSnapshot: Equatable {
    struct ExerciseSignature: Equatable {
        let name: String
        let sets: Int?
        let reps: Int?
        let weight: Double?
        let subcategoryID: UUID?

        init(_ entry: ExerciseLogEntry) {
            self.name = entry.trimmedName
            self.sets = entry.sets
            self.reps = entry.reps
            self.weight = entry.weight
            self.subcategoryID = entry.subcategoryID
        }

        init(name: String, sets: Int?, reps: Int?, weight: Double?, subcategoryID: UUID?) {
            self.name = name
            self.sets = sets
            self.reps = reps
            self.weight = weight
            self.subcategoryID = subcategoryID
        }
    }

    let type: WorkoutType
    let date: Date
    let durationMinutes: Double
    let distanceKilometers: Double
    let workoutRating: Double?
    let notes: String
    let selectedCategoryIDs: [UUID]
    let selectedSubcategoryIDs: [UUID]
    let exerciseSignatures: [ExerciseSignature]

    init(workout: Workout) {
        self.type = workout.type
        self.date = workout.startDate
        self.durationMinutes = workout.duration / 60
        self.distanceKilometers = workout.distance ?? 0
        self.workoutRating = workout.rating
        self.notes = workout.notes ?? ""
        self.selectedCategoryIDs = (workout.categories ?? []).map(\.id)
        self.selectedSubcategoryIDs = (workout.subcategories ?? []).map(\.id)
        self.exerciseSignatures = (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                ExerciseSignature(
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    sets: $0.sets,
                    reps: $0.reps,
                    weight: $0.weight,
                    subcategoryID: $0.subcategory?.id
                )
            }
    }

    init(
        type: WorkoutType,
        date: Date,
        durationMinutes: Double,
        distanceKilometers: Double,
        workoutRating: Double?,
        notes: String,
        selectedCategoryIDs: [UUID],
        selectedSubcategoryIDs: [UUID],
        exerciseSignatures: [ExerciseSignature]
    ) {
        self.type = type
        self.date = date
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.workoutRating = workoutRating
        self.notes = notes
        self.selectedCategoryIDs = selectedCategoryIDs
        self.selectedSubcategoryIDs = selectedSubcategoryIDs
        self.exerciseSignatures = exerciseSignatures
    }
}

// MARK: - Reorderable Exercise List

private struct ReorderableExerciseList: View {
    @Binding var entries: [ExerciseLogEntry]
    let colorScheme: ColorScheme
    let onTap: (ExerciseLogEntry) -> Void

    @State private var draggingItem: ExerciseLogEntry?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(entries) { entry in
                Button {
                    onTap(entry)
                } label: {
                    ExerciseCardView(
                        entry: entry,
                        showDragHandle: true,
                        isDragging: draggingItem?.id == entry.id,
                        colorScheme: colorScheme
                    )
                }
                .buttonStyle(.plain)
                .zIndex(draggingItem?.id == entry.id ? 1 : 0)
                .onDrag {
                    HapticManager.lightImpact()
                    draggingItem = entry
                    return NSItemProvider(object: entry.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: ExerciseDropDelegate(
                    item: entry,
                    entries: $entries,
                    draggingItem: $draggingItem
                ))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: entries.map(\.id))
    }
}

private struct ExerciseDropDelegate: DropDelegate {
    let item: ExerciseLogEntry
    @Binding var entries: [ExerciseLogEntry]
    @Binding var draggingItem: ExerciseLogEntry?

    func dropEntered(info: DropInfo) {
        guard let draggingItem,
              draggingItem.id != item.id,
              let fromIndex = entries.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = entries.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        HapticManager.lightImpact()

        withAnimation(.easeInOut(duration: 0.2)) {
            entries.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            draggingItem = nil
        }
        return true
    }

    func dropExited(info: DropInfo) {
        // Don't clear draggingItem here - only clear when drop is performed
    }
}

private struct EditTypeOptionButton: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? type.tintColor : .secondary)
                    .frame(height: 28)
                Text(type.rawValue)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(isSelected ? type.tintColor.opacity(0.15) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
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
