import SwiftUI

struct ExerciseSessionCard: View {
    @Binding var entry: ExerciseLogEntry
    @Binding var isExpanded: Bool
    let subcategoryName: String?
    let affectedSubcategoryNames: [String]
    let tintColor: Color
    let measurementSystem: MeasurementSystem
    let restTimerEnabled: Bool
    let restDurationSeconds: Int
    let onEditMetadata: () -> Void
    let onStartRest: () -> Void
    let onEditEffortScore: (() -> Void)?
    let onViewExercisePage: (() -> Void)?

    init(
        entry: Binding<ExerciseLogEntry>,
        isExpanded: Binding<Bool>,
        subcategoryName: String?,
        affectedSubcategoryNames: [String] = [],
        tintColor: Color,
        measurementSystem: MeasurementSystem,
        restTimerEnabled: Bool,
        restDurationSeconds: Int,
        onEditMetadata: @escaping () -> Void,
        onStartRest: @escaping () -> Void,
        onEditEffortScore: (() -> Void)? = nil,
        onViewExercisePage: (() -> Void)? = nil
    ) {
        self._entry = entry
        self._isExpanded = isExpanded
        self.subcategoryName = subcategoryName
        self.affectedSubcategoryNames = affectedSubcategoryNames
        self.tintColor = tintColor
        self.measurementSystem = measurementSystem
        self.restTimerEnabled = restTimerEnabled
        self.restDurationSeconds = restDurationSeconds
        self.onEditMetadata = onEditMetadata
        self.onStartRest = onStartRest
        self.onEditEffortScore = onEditEffortScore
        self.onViewExercisePage = onViewExercisePage
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            exerciseContent
        } label: {
            exerciseLabel
                .contextMenu {
                    Button {
                        onEditMetadata()
                    } label: {
                        Label("Edit Exercise", systemImage: "slider.horizontal.3")
                    }

                    if let onViewExercisePage {
                        Button {
                            onViewExercisePage()
                        } label: {
                            Label("View Exercise Page", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }
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

                if !affectedSubcategoryNames.isEmpty {
                    Text("Affects: \(affectedSubcategoryNames.joined(separator: ", "))")
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
            Label {
                Text("No sets logged yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "list.number")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
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
                    onStartRest: nil
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
            exerciseActionLabel(entry.setEntries.isEmpty ? "Log First Set" : "Log Set", systemImage: "plus.circle")
        }
        .buttonStyle(.plain)

        if !entry.setEntries.isEmpty {
            Button {
                ExerciseSessionActions.addSet(entry: &entry, measurementSystem: measurementSystem)
            } label: {
                exerciseActionLabel("Add Set", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }

        if let onEditEffortScore {
            Button {
                onEditEffortScore()
            } label: {
                RatingPickerRow(
                    title: "Toughness",
                    rating: entry.effortScore,
                    placeholder: "Add",
                    tintColor: tintColor
                )
            }
            .buttonStyle(.plain)
        }

        Button(action: onEditMetadata) {
            exerciseActionLabel("Edit Exercise", systemImage: "pencil")
        }
        .buttonStyle(.plain)
    }

    private func exerciseActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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
