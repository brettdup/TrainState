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
    let quickLogSaveAction: (() -> Void)?
    let mode: Mode
    let scope: Scope

    @AppStorage("measurementSystem") private var measurementSystemRaw = MeasurementSystem.metric.rawValue
    @FocusState private var focusedField: Field?
    @State private var isCreatingCustomExercise = false
    @State private var activePickerEditor: PickerEditor?
    @State private var showingCategoryBrowser = false

    private var measurementSystem: MeasurementSystem {
        MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric
    }

    private enum Field: Hashable {
        case name
    }

    enum Mode {
        case workout
        case template
    }

    enum Scope {
        case full
        case metadataOnly
    }

    private enum PickerEditor: Hashable, Identifiable {
        case reps(UUID)
        case weight(UUID)

        var id: String {
            switch self {
            case .reps(let id):
                return "reps-\(id.uuidString)"
            case .weight(let id):
                return "weight-\(id.uuidString)"
            }
        }

        var metric: SetMetricStepperSheet.Metric {
            switch self {
            case .reps:
                return .reps
            case .weight:
                return .weight
            }
        }

        var setID: UUID {
            switch self {
            case .reps(let id), .weight(let id):
                return id
            }
        }
    }

    init(
        entry: Binding<ExerciseLogEntry>,
        availableSubcategories: [WorkoutSubcategory],
        availableOptions: [ExerciseQuickAddOption],
        onDelete: @escaping () -> Void,
        quickLogSaveAction: (() -> Void)? = nil,
        mode: Mode = .workout,
        scope: Scope = .full
    ) {
        self._entry = entry
        self.availableSubcategories = availableSubcategories
        self.availableOptions = availableOptions
        self.onDelete = onDelete
        self.quickLogSaveAction = quickLogSaveAction
        self.mode = mode
        self.scope = scope
    }

    private var showsSetEditing: Bool {
        scope == .full || mode == .template
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
            List {
                Section("Exercise") {
                    if !availableSubcategories.isEmpty {
                        subcategoryMenuRow
                    }

                    if !exerciseNamesForPicker.isEmpty {
                        exerciseMenuRow
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
                    if let score = entry.effortScore {
                        Stepper(value: effortScoreBinding, in: 1...10) {
                            LabeledContent("Toughness", value: "\(score) / 10")
                        }

                        Button("Clear Toughness", role: .destructive) {
                            entry.effortScore = nil
                        }
                    } else {
                        Button {
                            entry.effortScore = 5
                        } label: {
                            Label("Add Toughness Score", systemImage: "gauge.medium")
                        }
                    }
                } footer: {
                    Text("Rate how tough this exercise felt from 1 to 10.")
                }

                if showsSetEditing {
                Section {
                    HStack {
                        Text("Sets")
                        Spacer()
                        Button {
                            adjustSetCount(by: -1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Text("\(entry.effectiveSetCount ?? 0)")
                            .font(.headline.monospacedDigit())
                            .frame(minWidth: 24)

                        Button {
                            adjustSetCount(by: 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Details")
                } footer: {
                    Text(isReadyToSave ? "Changes apply automatically." : "Add an exercise name to keep this entry.")
                }

                Section("Set Plan") {
                    if entry.setEntries.isEmpty {
                        ContentUnavailableView(
                            "No Set Plan Yet",
                            systemImage: "list.number",
                            description: Text("Add sets inline or start with a quick set count.")
                        )
                        .listRowBackground(Color.clear)

                        quickSetCountRow
                    } else {
                        ForEach(Array(entry.setEntries.enumerated()), id: \.element.id) { index, setEntry in
                            setPlanRow(index: index, setEntry: setEntry)
                        }
                    }

                    Button {
                        addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle.fill")
                    }

                    if mode == .workout, !entry.setEntries.isEmpty {
                        Text("\(entry.completedSetCount)/\(entry.setEntries.count) sets completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                }

                if scope == .metadataOnly {
                    Section {
                        Text("Sets are logged on the workout screen. Expand the exercise card to add or edit sets.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let quickLogSaveAction {
                    Section {
                        Text("Adds to today's strength workout when you save.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            quickLogSaveAction()
                        } label: {
                            Label("Save to Quick Log", systemImage: "tray.and.arrow.down.fill")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!isReadyToSave)
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
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(
                quickLogSaveAction != nil
                    ? "Log a Set"
                    : scope == .metadataOnly
                        ? (entry.trimmedName.isEmpty ? "Exercise" : entry.trimmedName)
                        : (entry.trimmedName.isEmpty ? "New Exercise" : "Edit Exercise")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
        .presentationDetents([.large])
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
        .onChange(of: entry.name) { _, newName in
            guard entry.subcategoryID == nil else { return }
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let match = availableOptions.first(where: {
                $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
            }) {
                entry.subcategoryID = match.subcategoryID
            }
        }
        .sheet(item: $activePickerEditor) { editor in
            if showsSetEditing {
                SetMetricStepperSheet(
                    metric: editor.metric,
                    measurementSystem: measurementSystem,
                    reps: repsBinding(for: editor.setID),
                    weight: weightBinding(for: editor.setID)
                )
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingCategoryBrowser) {
            UnifiedExercisePickerView(
                subcategories: availableSubcategories,
                exerciseOptions: availableOptions,
                existingExerciseNames: [],
                onSelect: { selected in
                    if let option = selected.first {
                        entry.subcategoryID = option.subcategoryID
                        entry.name = option.name
                    }
                },
                onCreateCustom: { name, subcategoryID in
                    entry.subcategoryID = subcategoryID
                    entry.name = name
                }
            )
        }
    }

    private var subcategoryMenuRow: some View {
        HStack {
            Text("Subcategory")
            Spacer(minLength: 12)
            Menu {
                ForEach(availableSubcategories, id: \.id) { subcategory in
                    Button {
                        entry.subcategoryID = subcategory.id
                    } label: {
                        if entry.subcategoryID == subcategory.id {
                            Label(subcategory.name, systemImage: "checkmark")
                        } else {
                            Text(subcategory.name)
                        }
                    }
                }
            } label: {
                menuValueLabel(selectedSubcategoryTitle)
            }
        }
    }

    private var exerciseMenuRow: some View {
        HStack {
            Text("Exercise")
            Spacer(minLength: 12)
            Menu {
                ForEach(exerciseNamesForPicker, id: \.self) { name in
                    Button {
                        isCreatingCustomExercise = false
                        entry.name = name
                        focusedField = nil
                    } label: {
                        if !isCreatingCustomExercise && entry.trimmedName == name {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
                Button {
                    isCreatingCustomExercise = true
                    if exerciseNamesForPicker.contains(entry.trimmedName) {
                        entry.name = ""
                    }
                    focusedField = .name
                } label: {
                    if isCreatingCustomExercise {
                        Label("New Exercise...", systemImage: "checkmark")
                    } else {
                        Text("New Exercise...")
                    }
                }
            } label: {
                menuValueLabel(exerciseMenuTitle)
            }
        }
    }

    private var selectedSubcategoryTitle: String {
        guard let id = entry.subcategoryID,
              let subcategory = availableSubcategories.first(where: { $0.id == id }) else {
            return "Select"
        }
        return subcategory.name
    }

    private var exerciseMenuTitle: String {
        if isCreatingCustomExercise {
            return "New Exercise..."
        }
        if entry.trimmedName.isEmpty {
            return "Select"
        }
        return entry.trimmedName
    }

    @ViewBuilder
    private func menuValueLabel(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func setPlanRow(index: Int, setEntry: ExerciseSetEntry) -> some View {
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
                SetMetricCapsuleButton(label: "Reps", value: "\(setEntry.reps)")
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.lightImpact()
                activePickerEditor = .weight(setEntry.id)
            } label: {
                let display = MeasurementFormatting.displayWeightFromStorage(
                    setEntry.weight,
                    system: measurementSystem
                )
                SetMetricCapsuleButton(
                    label: MeasurementFormatting.weightUnitLabel(for: measurementSystem),
                    value: MeasurementFormatting.displayWeight(display, system: measurementSystem)
                )
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                duplicateSet(setID: setEntry.id)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.blue)
        }

        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteSet(setEntry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .contextMenu {
            Button {
                duplicateSet(setID: setEntry.id)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive) {
                deleteSet(setEntry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var quickSetCountRow: some View {
        HStack(spacing: 8) {
            ForEach([3, 4, 5], id: \.self) { count in
                Button {
                    setSetCount(count)
                } label: {
                    Text("\(count) Sets")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func repsBinding(for setID: UUID) -> Binding<Int> {
        Binding(
            get: {
                entry.setEntries.first(where: { $0.id == setID })?.reps ?? 0
            },
            set: { newValue in
                guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
                entry.setEntries[idx].reps = newValue
                syncLegacyMetricsFromFirstSet()
            }
        )
    }

    private func weightBinding(for setID: UUID) -> Binding<Double> {
        Binding(
            get: {
                entry.setEntries.first(where: { $0.id == setID })?.weight ?? 0
            },
            set: { newValue in
                guard let idx = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
                entry.setEntries[idx].weight = newValue
                syncLegacyMetricsFromFirstSet()
            }
        )
    }

    private func exerciseNames(for subcategoryID: UUID) -> [String] {
        let names = availableOptions
            .filter { $0.subcategoryID == subcategoryID }
            .map(\.name)
        return Array(Set(names)).sorted()
    }

    private var effortScoreBinding: Binding<Int> {
        Binding(
            get: { entry.effortScore ?? 5 },
            set: { entry.effortScore = min(max($0, 1), 10) }
        )
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

    private func setSetCount(_ count: Int) {
        entry.sets = count > 0 ? count : nil
        syncPlannedSetEntriesFromMetrics()
        syncLegacyMetricsFromFirstSet()
        HapticManager.lightImpact()
    }

    private func adjustSetCount(by delta: Int) {
        let next = max((entry.effectiveSetCount ?? 0) + delta, 0)
        setSetCount(next)
    }

    private func addSet() {
        if let last = entry.setEntries.last {
            entry.setEntries.append(
                ExerciseSetEntry(
                    reps: last.reps,
                    weight: last.weight,
                    isCompleted: false
                )
            )
        } else {
            entry.setEntries.append(
                ExerciseSetEntry(
                    reps: max(entry.reps ?? 0, 0),
                    weight: max(entry.weight ?? 0, 0),
                    isCompleted: false
                )
            )
        }
        entry.sets = entry.setEntries.count
        syncLegacyMetricsFromFirstSet()
        HapticManager.lightImpact()
    }

    private func deleteSet(_ setID: UUID) {
        guard let index = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
        entry.setEntries.remove(at: index)
        entry.sets = entry.setEntries.isEmpty ? nil : entry.setEntries.count
        syncLegacyMetricsFromFirstSet()
        HapticManager.lightImpact()
    }

    private func duplicateSet(setID: UUID) {
        guard let index = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
        let source = entry.setEntries[index]
        let duplicate = ExerciseSetEntry(
            reps: source.reps,
            weight: source.weight,
            isCompleted: false
        )
        entry.setEntries.insert(duplicate, at: index + 1)
        entry.sets = entry.setEntries.count
        syncLegacyMetricsFromFirstSet()
        HapticManager.lightImpact()
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
