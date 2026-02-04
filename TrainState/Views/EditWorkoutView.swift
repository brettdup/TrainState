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
    @State private var notes: String
    @State private var selectedCategories: [WorkoutCategory]
    @State private var selectedSubcategories: [WorkoutSubcategory]
    @State private var exerciseEntries: [ExerciseLogEntry]
    @State private var showingCategoryPicker = false
    @State private var showingExercisePicker = false
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var isSaving = false
    @State private var showingExerciseLinkAlert = false

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
    private var showsDistance: Bool {
        [.running, .cycling, .swimming].contains(type)
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
        _type = State(initialValue: workout.type)
        _date = State(initialValue: workout.startDate)
        _durationMinutes = State(initialValue: workout.duration / 60)
        _distanceKilometers = State(initialValue: workout.distance ?? 0)
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
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    typeCard
                    dateCard
                    durationCard
                    if showsDistance { distanceCard }
                    categoriesCard
                    exercisesCard
                    notesCard
                    saveButton
                }
                .glassEffectContainer(spacing: 20)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
            ExerciseOptionPickerView(
                options: quickAddOptions,
                subcategories: availableExerciseSubcategories
            ) { option in
                addExercise(from: option)
            }
        }
        .sheet(item: $activeExerciseSelection) { selection in
            if let index = exerciseEntries.firstIndex(where: { $0.id == selection.id }) {
                ExerciseEditorSheetView(
                    entry: $exerciseEntries[index],
                    availableSubcategories: availableExerciseSubcategories,
                    availableOptions: quickAddOptions,
                    onDelete: {
                        exerciseEntries.remove(at: index)
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
            // When leaving the editor page, clean up any fully empty exercises
            if newValue == nil {
                exerciseEntries.removeAll { $0.isEmpty }
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
        .glassCard(cornerRadius: 32)
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
        .glassCard(cornerRadius: 32)
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
        .glassCard(cornerRadius: 32)
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
        .glassCard(cornerRadius: 32)
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
        .glassCard(cornerRadius: 32)
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addAndEditNewExercise()
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(type.tintColor.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }

            if !quickAddOptions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick add from your templates")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickAddOptions) { option in
                                Button {
                                    addExercise(from: option)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                            .font(.caption2)
                                        Text(option.name)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(type.tintColor.opacity(0.18))
                                    )
                                    .foregroundStyle(type.tintColor)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                showingExercisePicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.caption2)
                                    Text("Browse all")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if exerciseEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No exercises yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Use quick-add chips above or add a custom exercise to start tracking sets, reps, and weight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(exerciseEntries) { entry in
                        Button {
                            activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.trimmedName.isEmpty ? "Unnamed exercise" : entry.trimmedName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if let summary = exerciseSummary(for: entry) {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if quickAddOptions.isEmpty {
                Text("Select workout subcategories to unlock quick-add exercise chips.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .fill(Color(.systemBackground).opacity(colorScheme == .dark ? 0.9 : 0.96))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 6)
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
        .glassCard(cornerRadius: 32)
    }

    private var saveButton: some View {
        Button {
            guard !isSaving else { return }
            guard !hasUnlinkedExercises(exerciseEntries) else {
                showingExerciseLinkAlert = true
                return
            }
            isSaving = true
            persistExerciseTemplates(from: exerciseEntries)

            workout.type = type
            workout.startDate = date
            workout.duration = durationMinutes * 60
            workout.distance = showsDistance && distanceKilometers > 0 ? distanceKilometers : nil
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

    private func hasUnlinkedExercises(_ entries: [ExerciseLogEntry]) -> Bool {
        entries.contains { !$0.trimmedName.isEmpty && $0.subcategoryID == nil }
    }

    private func addAndEditNewExercise() {
        let newEntry = defaultExerciseEntry()
        exerciseEntries.append(newEntry)
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
