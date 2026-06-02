import SwiftUI

struct ExerciseSessionCard: View {
    @Binding var entry: ExerciseLogEntry
    @Binding var isExpanded: Bool
    let subcategoryName: String?
    let tintColor: Color
    let measurementSystem: MeasurementSystem
    let restTimerEnabled: Bool
    let restDurationSeconds: Int
    let onEditMetadata: () -> Void
    let onStartRest: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            exerciseContent
        } label: {
            exerciseLabel
        }
        .tint(tintColor)
    }

    private var exerciseLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: ExerciseIconMapper.icon(for: entry.trimmedName))
                .foregroundStyle(ExerciseIconMapper.iconColor(for: entry.trimmedName))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.trimmedName.isEmpty ? "Unnamed Exercise" : entry.trimmedName)
                    .font(.body)

                if let subcategoryName, !subcategoryName.isEmpty {
                    Text(subcategoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !isExpanded {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let score = entry.effortScore {
                    Label("\(score)/10 tough", systemImage: "gauge.medium")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var exerciseContent: some View {
        if entry.setEntries.isEmpty {
            Picker("Quick start", selection: quickStartSelection) {
                Text("3 sets").tag(3)
                Text("4 sets").tag(4)
                Text("5 sets").tag(5)
            }
            .pickerStyle(.segmented)
        } else {
            ForEach($entry.setEntries) { $setEntry in
                let index = entry.setEntries.firstIndex(where: { $0.id == setEntry.id }) ?? 0
                ExerciseSetInlineRow(
                    setEntry: $setEntry,
                    setIndex: index,
                    measurementSystem: measurementSystem,
                    showsCompletion: true,
                    onDuplicate: { duplicateSet(id: setEntry.id) },
                    onDelete: { deleteSet(id: setEntry.id) },
                    onStartRest: restTimerEnabled ? onStartRest : nil
                )
            }

            LabeledContent("Completed") {
                Text("\(entry.completedSetCount) of \(entry.setEntries.count)")
                    .foregroundStyle(.secondary)
            }
        }

        Button {
            ExerciseSessionActions.logNextSet(entry: &entry, measurementSystem: measurementSystem)
        } label: {
            Label("Log Set", systemImage: "plus.circle.fill")
        }

        if !entry.setEntries.isEmpty {
            Button {
                ExerciseSessionActions.addSet(entry: &entry, measurementSystem: measurementSystem)
            } label: {
                Label("Add Set", systemImage: "plus")
            }
        }

        if let markLabel = ExerciseSessionActions.nextSetCompletionLabel(for: entry) {
            Button {
                ExerciseSessionActions.markNextSetDone(entry: &entry)
            } label: {
                Label(markLabel, systemImage: "checkmark.circle")
            }
        }

        Button(action: onEditMetadata) {
            Label("Edit Exercise", systemImage: "pencil")
        }
    }

    private var quickStartSelection: Binding<Int> {
        Binding(
            get: { entry.setEntries.isEmpty ? 3 : entry.setEntries.count },
            set: { count in
                guard (3...5).contains(count) else { return }
                entry.setEntries = (0..<count).map { _ in
                    ExerciseSetEntry(
                        reps: entry.effectiveReps ?? 8,
                        weight: entry.effectiveWeight ?? defaultWeight
                    )
                }
                ExerciseSessionActions.syncLegacyMetrics(&entry)
            }
        )
    }

    private var summaryText: String {
        if entry.setEntries.isEmpty {
            return "No sets logged yet"
        }
        if let last = entry.setEntries.last {
            let weightLabel = MeasurementFormatting.displayWeight(last.weight, system: measurementSystem)
            let unit = MeasurementFormatting.weightUnitLabel(for: measurementSystem)
            return "\(entry.completedSetCount)/\(entry.setEntries.count) sets · \(last.reps) × \(weightLabel) \(unit)"
        }
        return "\(entry.completedSetCount)/\(entry.setEntries.count) sets"
    }

    private var defaultWeight: Double {
        measurementSystem == .imperial ? 45 / 2.20462 : 20
    }

    private func duplicateSet(id: UUID) {
        guard let index = entry.setEntries.firstIndex(where: { $0.id == id }) else { return }
        var copy = entry.setEntries[index]
        copy.id = UUID()
        entry.setEntries.insert(copy, at: index + 1)
        ExerciseSessionActions.syncLegacyMetrics(&entry)
    }

    private func deleteSet(id: UUID) {
        guard let index = entry.setEntries.firstIndex(where: { $0.id == id }) else { return }
        entry.setEntries.remove(at: index)
        ExerciseSessionActions.syncLegacyMetrics(&entry)
    }
}
