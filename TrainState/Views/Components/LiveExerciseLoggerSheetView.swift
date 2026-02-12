import SwiftUI

struct LiveExerciseLoggerSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var entry: ExerciseLogEntry
    let availableSubcategories: [WorkoutSubcategory]
    let availableOptions: [ExerciseQuickAddOption]
    let onDelete: () -> Void

    @FocusState private var focusedField: Bool
    @State private var activeMetricEditor: SetMetricEditor?

    private enum SetMetric: String {
        case reps
        case weight
    }

    private struct SetMetricEditor: Identifiable {
        let setID: UUID
        let metric: SetMetric

        var id: String { "\(setID.uuidString)-\(metric.rawValue)" }
    }

    private var availableExerciseNames: [String] {
        guard let subcategoryID = entry.subcategoryID else { return [] }
        let names = availableOptions
            .filter { $0.subcategoryID == subcategoryID }
            .map(\.name)
        return Array(Set(names)).sorted()
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
                    }

                    if !availableExerciseNames.isEmpty {
                        Picker("Exercise", selection: nameBinding) {
                            ForEach(availableExerciseNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    } else {
                        TextField("Exercise name", text: $entry.name)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($focusedField)
                    }
                }

                Section("Sets") {
                    if entry.setEntries.isEmpty {
                        ContentUnavailableView(
                            "No Sets Yet",
                            systemImage: "list.number",
                            description: Text("Tap Add Set to log reps and weight.")
                        )
                    } else {
                        Text("\(entry.completedSetCount)/\(entry.setEntries.count) sets completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(entry.setEntries.enumerated()), id: \.element.id) { index, setEntry in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button {
                                        toggleSetCompletion(setID: setEntry.id)
                                    } label: {
                                        Label(
                                            setEntry.isCompleted ? "Done" : "Mark Done",
                                            systemImage: setEntry.isCompleted ? "checkmark.circle.fill" : "circle"
                                        )
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(setEntry.isCompleted ? Color.green : Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 12) {
                                    metricButton(
                                        title: "Reps",
                                        value: "\(setEntry.reps)",
                                        setID: setEntry.id,
                                        metric: .reps
                                    )

                                    metricButton(
                                        title: "Weight",
                                        value: ExerciseLogEntry.displayWeight(setEntry.weight),
                                        suffix: "kg",
                                        setID: setEntry.id,
                                        metric: .weight
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteSet)
                    }

                    Button {
                        addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle.fill")
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
            .navigationTitle(entry.trimmedName.isEmpty ? "Live Exercise" : entry.trimmedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if entry.subcategoryID == nil, let first = availableSubcategories.first {
                entry.subcategoryID = first.id
            }
        }
        .sheet(item: $activeMetricEditor) { editor in
            setMetricEditorSheet(editor)
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var subcategoryBinding: Binding<UUID?> {
        Binding(
            get: { entry.subcategoryID },
            set: { newValue in
                entry.subcategoryID = newValue
                if !availableExerciseNames.contains(entry.trimmedName),
                   let first = availableExerciseNames.first {
                    entry.name = first
                }
            }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { entry.trimmedName },
            set: { entry.name = $0 }
        )
    }

    private func addSet() {
        if let last = entry.setEntries.last {
            entry.setEntries.append(ExerciseSetEntry(reps: last.reps, weight: last.weight, isCompleted: false))
        } else {
            let reps = max(entry.reps ?? 8, 1)
            let weight = max(entry.weight ?? 20, 0)
            entry.setEntries.append(ExerciseSetEntry(reps: reps, weight: weight, isCompleted: false))
        }
        entry.sets = entry.setEntries.count
        if let first = entry.setEntries.first {
            entry.reps = first.reps
            entry.weight = first.weight
        }
    }

    private func deleteSet(at offsets: IndexSet) {
        entry.setEntries.remove(atOffsets: offsets)
        entry.sets = entry.setEntries.isEmpty ? nil : entry.setEntries.count
        if let first = entry.setEntries.first {
            entry.reps = first.reps
            entry.weight = first.weight
        } else {
            entry.reps = nil
            entry.weight = nil
        }
    }

    @ViewBuilder
    private func metricButton(
        title: String,
        value: String,
        suffix: String? = nil,
        setID: UUID,
        metric: SetMetric
    ) -> some View {
        Button {
            HapticManager.lightImpact()
            activeMetricEditor = SetMetricEditor(setID: setID, metric: metric)
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
    private func setMetricEditorSheet(_ editor: SetMetricEditor) -> some View {
        VStack(spacing: 18) {
            Text(editor.metric == .reps ? "Reps" : "Weight (kg)")
                .font(.headline)

            Text(setMetricValueString(editor))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button {
                    adjust(editor: editor, delta: -metricStep(editor.metric))
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
                    adjust(editor: editor, delta: metricStep(editor.metric))
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

    private func setMetricValueString(_ editor: SetMetricEditor) -> String {
        guard let set = entry.setEntries.first(where: { $0.id == editor.setID }) else { return "-" }
        switch editor.metric {
        case .reps:
            return "\(set.reps)"
        case .weight:
            return ExerciseLogEntry.displayWeight(set.weight)
        }
    }

    private func metricStep(_ metric: SetMetric) -> Double {
        switch metric {
        case .reps: return 1
        case .weight: return 2.5
        }
    }

    private func adjust(editor: SetMetricEditor, delta: Double) {
        guard let idx = entry.setEntries.firstIndex(where: { $0.id == editor.setID }) else { return }
        switch editor.metric {
        case .reps:
            let current = Double(entry.setEntries[idx].reps)
            entry.setEntries[idx].reps = max(Int(current + delta), 0)
        case .weight:
            let current = entry.setEntries[idx].weight
            entry.setEntries[idx].weight = max(current + delta, 0)
        }
        syncLegacySummaryValues()
        HapticManager.lightImpact()
    }

    private func clear(editor: SetMetricEditor) {
        guard let idx = entry.setEntries.firstIndex(where: { $0.id == editor.setID }) else { return }
        switch editor.metric {
        case .reps:
            entry.setEntries[idx].reps = 0
        case .weight:
            entry.setEntries[idx].weight = 0
        }
        syncLegacySummaryValues()
        HapticManager.lightImpact()
    }

    private func syncLegacySummaryValues() {
        entry.sets = entry.setEntries.count
        if let first = entry.setEntries.first {
            entry.reps = first.reps
            entry.weight = first.weight
        } else {
            entry.reps = nil
            entry.weight = nil
        }
    }

    private func toggleSetCompletion(setID: UUID) {
        guard let index = entry.setEntries.firstIndex(where: { $0.id == setID }) else { return }
        entry.setEntries[index].isCompleted.toggle()
        HapticManager.lightImpact()
    }
}
