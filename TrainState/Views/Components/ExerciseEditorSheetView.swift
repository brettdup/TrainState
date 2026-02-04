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

    @FocusState private var focusedField: Field?
    @State private var isCreatingCustomExercise = false
    @State private var activeMetricEditor: MetricEditor?

    private enum Field: Hashable {
        case name
    }

    private enum MetricEditor: String, Identifiable {
        case sets
        case reps
        case weight

        var id: String { rawValue }
    }

    private let newExercisePickerValue = "__new_exercise__"

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

    private var detailCompletionCount: Int {
        var count = 0
        if entry.sets != nil { count += 1 }
        if entry.reps != nil { count += 1 }
        if entry.weight != nil { count += 1 }
        return count
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
                }

                Section {
                    VStack(spacing: 10) {
                        metricCard(title: "Sets", value: entry.sets.map(String.init) ?? "-", metric: .sets)
                        metricCard(title: "Reps", value: entry.reps.map(String.init) ?? "-", metric: .reps)
                        metricCard(
                            title: "Weight",
                            value: entry.weight.map(displayValue) ?? "-",
                            suffix: "kg",
                            metric: .weight
                        )
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Details")
                } footer: {
                    HStack {
                        Text(isReadyToSave ? "Ready to save" : "Add an exercise name to save")
                        Spacer()
                        Text("\(detailCompletionCount)/3")
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
            syncExerciseSelectionForCurrentSubcategory()
        }
        .onChange(of: entry.subcategoryID) { _, _ in
            syncExerciseSelectionForCurrentSubcategory()
        }
        .sheet(item: $activeMetricEditor) { metric in
            metricEditorSheet(metric: metric)
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
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
    private func metricCard(
        title: String,
        value: String,
        suffix: String? = nil,
        metric: MetricEditor
    ) -> some View {
        Button {
            HapticManager.lightImpact()
            activeMetricEditor = metric
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if let suffix {
                        Text(suffix)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricEditorSheet(metric: MetricEditor) -> some View {
        VStack(spacing: 18) {
            Text(metricTitle(metric))
                .font(.headline)

            Text(metricValueString(metric))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button {
                    adjust(metric: metric, delta: -metricStep(metric))
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    clearMetric(metric)
                } label: {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    adjust(metric: metric, delta: metricStep(metric))
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

        if trimmedName.isEmpty {
            entry.name = options[0]
            isCreatingCustomExercise = false
            return
        }

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

    private func metricTitle(_ metric: MetricEditor) -> String {
        switch metric {
        case .sets: return "Sets"
        case .reps: return "Reps"
        case .weight: return "Weight (kg)"
        }
    }

    private func metricValueString(_ metric: MetricEditor) -> String {
        switch metric {
        case .sets:
            return entry.sets.map(String.init) ?? "-"
        case .reps:
            return entry.reps.map(String.init) ?? "-"
        case .weight:
            return entry.weight.map(displayValue) ?? "-"
        }
    }

    private func metricStep(_ metric: MetricEditor) -> Double {
        switch metric {
        case .sets, .reps: return 1
        case .weight: return 2.5
        }
    }

    private func adjust(metric: MetricEditor, delta: Double) {
        let didChange: Bool
        switch metric {
        case .sets:
            let previous = entry.sets
            let current = Double(entry.sets ?? 0)
            let next = max(0, current + delta)
            entry.sets = next > 0 ? Int(next) : nil
            didChange = previous != entry.sets
        case .reps:
            let previous = entry.reps
            let current = Double(entry.reps ?? 0)
            let next = max(0, current + delta)
            entry.reps = next > 0 ? Int(next) : nil
            didChange = previous != entry.reps
        case .weight:
            let previous = entry.weight
            let current = entry.weight ?? 0
            let next = max(0, current + delta)
            entry.weight = next > 0 ? next : nil
            didChange = previous != entry.weight
        }

        if didChange {
            HapticManager.lightImpact()
        }
    }

    private func clearMetric(_ metric: MetricEditor) {
        let didChange: Bool
        switch metric {
        case .sets:
            didChange = entry.sets != nil
            entry.sets = nil
        case .reps:
            didChange = entry.reps != nil
            entry.reps = nil
        case .weight:
            didChange = entry.weight != nil
            entry.weight = nil
        }

        if didChange {
            HapticManager.lightImpact()
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
            }
        )
    }
}

#Preview("Exercise Editor - Empty") {
    ExerciseEditorSheetPreviewHost(mode: .empty)
}

#Preview("Exercise Editor - Filled") {
    ExerciseEditorSheetPreviewHost(mode: .filled)
}
