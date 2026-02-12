import SwiftUI

struct ExerciseEditorSelection: Identifiable, Hashable {
    let id: UUID
}

struct ExerciseEditorSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var entry: ExerciseLogEntry
    let availableSubcategories: [WorkoutSubcategory]
    let availableOptions: [ExerciseQuickAddOption]
    let onDelete: () -> Void
    let mode: Mode

    @FocusState private var focusedField: Field?
    @State private var isCreatingCustomExercise = false
    @State private var activePickerEditor: PickerEditor?
    @State private var showingCategoryBrowser = false

    private enum Field: Hashable {
        case name
    }

    enum Mode {
        case workout
        case template
    }

    private enum PickerEditor: Hashable, Identifiable {
        case sets
        case reps(UUID)
        case weight(UUID)

        var id: String {
            switch self {
            case .sets:
                return "sets"
            case .reps(let id):
                return "reps-\(id.uuidString)"
            case .weight(let id):
                return "weight-\(id.uuidString)"
            }
        }
    }

    private let newExercisePickerValue = "__new_exercise__"

    init(
        entry: Binding<ExerciseLogEntry>,
        availableSubcategories: [WorkoutSubcategory],
        availableOptions: [ExerciseQuickAddOption],
        onDelete: @escaping () -> Void,
        mode: Mode = .workout
    ) {
        self._entry = entry
        self.availableSubcategories = availableSubcategories
        self.availableOptions = availableOptions
        self.onDelete = onDelete
        self.mode = mode
    }

    private var exerciseNamesForSelectedSubcategory: [String] {
        guard let id = entry.subcategoryID else { return [] }
        return exerciseNames(for: id)
    }

    private var exerciseNamesForPicker: [String] {
        if !exerciseNamesForSelectedSubcategory.isEmpty {
            return exerciseNamesForSelectedSubcategory
        }

        let all = availableOptions.map(\.name)
        return Array(Set(all)).sorted()
    }

    private var isReadyToSave: Bool {
        !entry.trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    if !availableSubcategories.isEmpty {
                        Picker("Subcategory", selection: subcategoryBinding) {
                            ForEach(availableSubcategories, id: \.id) { subcategory in
                                Text(subcategory.name).tag(Optional(subcategory.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if !exerciseNamesForPicker.isEmpty {
                        Picker("Exercise", selection: exerciseSelectionBinding) {
                            ForEach(exerciseNamesForPicker, id: \.self) { name in
                                Text(name).tag(name)
                            }
                            Text("New Exercise...").tag(newExercisePickerValue)
                        }
                        .pickerStyle(.menu)
                    }

                    if isCreatingCustomExercise || exerciseNamesForPicker.isEmpty {
                        TextField("New exercise name", text: $entry.name)
                            .focused($focusedField, equals: .name)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                    }

                    if !availableSubcategories.isEmpty {
                        Button {
                            showingCategoryBrowser = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                Text("Browse by category")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        HapticManager.lightImpact()
                        activePickerEditor = .sets
                    } label: {
                        HStack {
                            Text("Sets")
                            Spacer()
                            Text("\(entry.effectiveSetCount ?? 0)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Details")
                } footer: {
                    Text(isReadyToSave ? "Ready to save" : "Add an exercise name to save")
                }

                if !entry.setEntries.isEmpty {
                    Section("Set Plan") {
                        ForEach(Array(entry.setEntries.enumerated()), id: \.element.id) { index, setEntry in
                            HStack(spacing: 12) {
                                if mode == .workout {
                                    Button {
                                        toggleSetCompletion(setID: setEntry.id)
                                    } label: {
                                        Image(systemName: setEntry.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(setEntry.isCompleted ? Color.green : Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text("Set \(index + 1)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 8)

                                Button {
                                    HapticManager.lightImpact()
                                    activePickerEditor = .reps(setEntry.id)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Reps")
                                        Text("\(setEntry.reps)")
                                            .monospacedDigit()
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.primary.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    HapticManager.lightImpact()
                                    activePickerEditor = .weight(setEntry.id)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Kg")
                                        Text(displayValue(setEntry.weight))
                                            .monospacedDigit()
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.primary.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if mode == .workout {
                            Text("\(entry.completedSetCount)/\(entry.setEntries.count) sets completed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !entry.isEmpty {
                    Section {
                        Button("Delete Exercise", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry.trimmedName.isEmpty ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(entry.trimmedName.isEmpty && entry.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if entry.subcategoryID == nil, let first = availableSubcategories.first {
                entry.subcategoryID = first.id
            }
            syncPlannedSetEntriesFromMetrics()
            syncExerciseSelectionForCurrentSubcategory()
        }
        .onChange(of: entry.subcategoryID) { _, _ in
            syncExerciseSelectionForCurrentSubcategory()
        }
        .sheet(item: $activePickerEditor) { editor in
            pickerEditorSheet(editor: editor)
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCategoryBrowser) {
            ExerciseCategoryBrowserView(
                subcategories: availableSubcategories,
                options: availableOptions
            ) { option in
                entry.subcategoryID = option.subcategoryID
                entry.name = option.name
            }
        }
    }

    private var subcategoryBinding: Binding<UUID?> {
        Binding(
            get: { entry.subcategoryID },
            set: { newValue in
                entry.subcategoryID = newValue
            }
        )
    }

    private var exerciseSelectionBinding: Binding<String> {
        Binding(
            get: {
                if isCreatingCustomExercise { return newExercisePickerValue }
                if exerciseNamesForPicker.contains(entry.trimmedName) {
                    return entry.trimmedName
                }
                return newExercisePickerValue
            },
            set: { newValue in
                if newValue == newExercisePickerValue {
                    isCreatingCustomExercise = true
                    if exerciseNamesForPicker.contains(entry.trimmedName) {
                        entry.name = ""
                    }
                    focusedField = .name
                } else {
                    isCreatingCustomExercise = false
                    entry.name = newValue
                    focusedField = nil
                }
            }
        )
    }

    @ViewBuilder
    private func pickerEditorSheet(editor: PickerEditor) -> some View {
        VStack(spacing: 18) {
            Text(pickerTitle(editor))
                .font(.headline)

            Text(pickerValueString(editor))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button {
                    adjust(editor: editor, delta: -pickerStep(editor))
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    clear(editor: editor)
                } label: {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    adjust(editor: editor, delta: pickerStep(editor))
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }

    private func exerciseNames(for subcategoryID: UUID) -> [String] {
        let names = availableOptions
            .filter { $0.subcategoryID == subcategoryID }
            .map(\.name)
        return Array(Set(names)).sorted()
    }

    private func syncExerciseSelectionForCurrentSubcategory() {
        let options = exerciseNamesForPicker
        let trimmedName = entry.trimmedName

        guard !options.isEmpty else {
            isCreatingCustomExercise = true
            return
        }

        // If the entry has no name yet, keep it as a custom exercise
        // instead of auto-filling from templates.
        if trimmedName.isEmpty {
            isCreatingCustomExercise = true
            return
        }

        // For named entries that match an option, keep them in-sync with that option.
        isCreatingCustomExercise = !options.contains(trimmedName)
        if !isCreatingCustomExercise, let matched = options.first(where: { $0 == trimmedName }) {
            entry.name = matched
        }
    }

    private func displayValue(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func pickerTitle(_ editor: PickerEditor) -> String {
        switch editor {
        case .sets:
            return "Sets"
        case .reps:
            return "Reps"
        case .weight:
            return "Weight (kg)"
        }
    }

    private func pickerValueString(_ editor: PickerEditor) -> String {
        switch editor {
        case .sets:
            return "\(entry.effectiveSetCount ?? 0)"
        case .reps(let setID):
            guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return "0" }
            return "\(entry.setEntries[idx].reps)"
        case .weight(let setID):
            guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return "0" }
            return displayValue(entry.setEntries[idx].weight)
        }
    }

    private func pickerStep(_ editor: PickerEditor) -> Double {
        switch editor {
        case .sets, .reps:
            return 1
        case .weight:
            return 2.5
        }
    }

    private func adjust(editor: PickerEditor, delta: Double) {
        switch editor {
        case .sets:
            let current = Double(entry.effectiveSetCount ?? 0)
            let next = max(0, Int(current + delta))
            entry.sets = next > 0 ? next : nil
            syncPlannedSetEntriesFromMetrics()
            syncLegacyMetricsFromFirstSet()
        case .reps(let setID):
            guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
            let current = Double(entry.setEntries[idx].reps)
            entry.setEntries[idx].reps = max(Int(current + delta), 0)
            syncLegacyMetricsFromFirstSet()
        case .weight(let setID):
            guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
            let current = entry.setEntries[idx].weight
            entry.setEntries[idx].weight = max(current + delta, 0)
            syncLegacyMetricsFromFirstSet()
        }
        HapticManager.lightImpact()
    }

    private func clear(editor: PickerEditor) {
        switch editor {
        case .sets:
            entry.sets = nil
            syncPlannedSetEntriesFromMetrics()
            syncLegacyMetricsFromFirstSet()
        case .reps(let setID):
            guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
            entry.setEntries[idx].reps = 0
            syncLegacyMetricsFromFirstSet()
        case .weight(let setID):
            guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
            entry.setEntries[idx].weight = 0
            syncLegacyMetricsFromFirstSet()
        }
        HapticManager.lightImpact()
    }

    private func syncPlannedSetEntriesFromMetrics() {
        let plannedCount = max(entry.sets ?? 0, 0)
        guard plannedCount > 0 else {
            entry.setEntries = []
            return
        }

        var sets = entry.setEntries
        if sets.count > plannedCount {
            sets = Array(sets.prefix(plannedCount))
        }
        while sets.count < plannedCount {
            let fallbackReps = max(entry.reps ?? sets.last?.reps ?? 0, 0)
            let fallbackWeight = max(entry.weight ?? sets.last?.weight ?? 0, 0)
            sets.append(
                ExerciseSetEntry(
                    reps: fallbackReps,
                    weight: fallbackWeight,
                    isCompleted: false
                )
            )
        }
        entry.setEntries = sets
    }

    private func toggleSetCompletion(setID: UUID) {
        guard let index = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
        entry.setEntries[index].isCompleted.toggle()
        HapticManager.lightImpact()
    }

    private func syncLegacyMetricsFromFirstSet() {
        if let first = entry.setEntries.first {
            entry.reps = first.reps
            entry.weight = first.weight
        } else {
            entry.reps = nil
            entry.weight = nil
        }
    }

}

private enum ExerciseEditorSheetPreviewData {
    static func make() -> (subcategories: [WorkoutSubcategory], options: [ExerciseQuickAddOption]) {
        let category = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
        let chest = WorkoutSubcategory(name: "Chest", category: category)
        let legs = WorkoutSubcategory(name: "Legs", category: category)

        let options = [
            ExerciseQuickAddOption(name: "Bench Press", subcategoryID: chest.id),
            ExerciseQuickAddOption(name: "Incline Dumbbell Press", subcategoryID: chest.id),
            ExerciseQuickAddOption(name: "Back Squat", subcategoryID: legs.id),
            ExerciseQuickAddOption(name: "Romanian Deadlift", subcategoryID: legs.id)
        ]

        return ([chest, legs], options)
    }
}

private struct ExerciseEditorSheetPreviewHost: View {
    enum Mode {
        case empty
        case filled
    }

    @State private var entry: ExerciseLogEntry
    private let availableSubcategories: [WorkoutSubcategory]
    private let availableOptions: [ExerciseQuickAddOption]

    init(mode: Mode) {
        let data = ExerciseEditorSheetPreviewData.make()
        self.availableSubcategories = data.subcategories
        self.availableOptions = data.options

        var entry = ExerciseLogEntry()
        entry.subcategoryID = data.subcategories.first?.id

        switch mode {
        case .empty:
            break
        case .filled:
            entry.name = "Bench Press"
            entry.sets = 4
            entry.reps = 8
            entry.weight = 80.0
        }

        _entry = State(initialValue: entry)
    }

    var body: some View {
        ExerciseEditorSheetView(
            entry: $entry,
            availableSubcategories: availableSubcategories,
            availableOptions: availableOptions,
            onDelete: {
                entry = ExerciseLogEntry(subcategoryID: availableSubcategories.first?.id)
            },
            mode: .workout
        )
    }
}

#Preview("Exercise Editor - Empty") {
    ExerciseEditorSheetPreviewHost(mode: .empty)
}

#Preview("Exercise Editor - Filled") {
    ExerciseEditorSheetPreviewHost(mode: .filled)
}
