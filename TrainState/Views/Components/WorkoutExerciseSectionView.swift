import SwiftUI
import SwiftData

struct WorkoutExerciseSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]

    @Binding var entries: [ExerciseLogEntry]
    @Binding var expandedExerciseIDs: Set<UUID>

    let tintColor: Color
    let availableSubcategories: [WorkoutSubcategory]
    let quickAddOptions: [ExerciseQuickAddOption]
    let workouts: [Workout]
    let measurementSystem: MeasurementSystem
    let restTimerEnabled: Bool
    let restDurationSeconds: Int
    let allowsReordering: Bool
    let onEditMetadata: (ExerciseLogEntry) -> Void
    let onStartRest: () -> Void

    @State private var showingExercisePicker = false
    @State private var activeRatingTarget: RatingPickerTarget?

    init(
        entries: Binding<[ExerciseLogEntry]>,
        tintColor: Color,
        availableSubcategories: [WorkoutSubcategory],
        quickAddOptions: [ExerciseQuickAddOption],
        workouts: [Workout] = [],
        exerciseTemplates: [SubcategoryExercise] = [],
        measurementSystem: MeasurementSystem = .metric,
        restTimerEnabled: Bool = false,
        restDurationSeconds: Int = 90,
        allowsReordering: Bool = false,
        expandedExerciseIDs: Binding<Set<UUID>> = .constant([]),
        onEditMetadata: @escaping (ExerciseLogEntry) -> Void = { _ in },
        onStartRest: @escaping () -> Void = {}
    ) {
        self._entries = entries
        self.tintColor = tintColor
        self.availableSubcategories = availableSubcategories
        self.quickAddOptions = quickAddOptions
        self.workouts = workouts
        self.measurementSystem = measurementSystem
        self.restTimerEnabled = restTimerEnabled
        self.restDurationSeconds = restDurationSeconds
        self.allowsReordering = allowsReordering
        self._expandedExerciseIDs = expandedExerciseIDs
        self.onEditMetadata = onEditMetadata
        self.onStartRest = onStartRest
    }

    var body: some View {
        Section {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "dumbbell",
                    description: Text("Add an exercise to start logging sets.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach($entries) { $entry in
                    let subcategoryName = availableSubcategories.first { $0.id == entry.subcategoryID }?.name
                    ExerciseSessionCard(
                        entry: $entry,
                        isExpanded: expansionBinding(for: entry.id),
                        subcategoryName: subcategoryName,
                        affectedSubcategoryNames: affectedSubcategoryNames(for: entry),
                        tintColor: tintColor,
                        measurementSystem: measurementSystem,
                        restTimerEnabled: restTimerEnabled,
                        restDurationSeconds: restDurationSeconds,
                        onEditMetadata: { onEditMetadata(entry) },
                        onStartRest: onStartRest,
                        onEditEffortScore: {
                            activeRatingTarget = RatingPickerTarget(
                                context: "exercise",
                                sourceID: entry.id,
                                title: entry.trimmedName.isEmpty ? "Toughness" : entry.trimmedName,
                                subtitle: "Rate how tough this exercise felt from 1 to 10.",
                                clearTitle: "Clear"
                            )
                        }
                    )
                }
                .onDelete(perform: deleteExercises)
            }

            Button {
                showingExercisePicker = true
            } label: {
                Label("Add Exercises", systemImage: "plus.circle.fill")
            }

            if quickAddOptions.isEmpty {
                Text("Assign workout categories to build your exercise library.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Exercises")
        } footer: {
            if !entries.isEmpty {
                Text("Expand an exercise to log sets. Swipe a set left or right to duplicate or delete.")
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            UnifiedExercisePickerView(
                subcategories: availableSubcategories,
                exerciseOptions: quickAddOptions,
                existingExerciseNames: Set(entries.map { $0.trimmedName.lowercased() }),
                onSelect: { selected in
                    for option in selected {
                        addExercise(from: option)
                    }
                },
                onCreateCustom: { name, subcategoryID in
                    saveExerciseTemplateIfNeeded(name: name, subcategoryID: subcategoryID)
                    var entry = ExerciseLogEntry(name: name, subcategoryID: subcategoryID)
                    ExerciseSessionActions.prefill(
                        entry: &entry,
                        workouts: workouts,
                        exerciseTemplates: exerciseTemplates
                    )
                    entries.append(entry)
                    expandedExerciseIDs.insert(entry.id)
                },
                tintColor: tintColor
            )
        }
        .sheet(item: $activeRatingTarget) { target in
            RatingPickerSheet(
                title: target.title,
                subtitle: target.subtitle,
                clearTitle: target.clearTitle,
                tintColor: tintColor,
                rating: effortScoreBinding(for: target.sourceID)
            )
            .presentationDetents([.fraction(0.58), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func effortScoreBinding(for entryID: UUID) -> Binding<Int?> {
        Binding(
            get: {
                entries.first { $0.id == entryID }?.effortScore
            },
            set: { newValue in
                guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
                entries[index].effortScore = newValue.map { min(max($0, 1), 10) }
            }
        )
    }

    private func expansionBinding(for entryID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedExerciseIDs.contains(entryID) },
            set: { isExpanded in
                if isExpanded {
                    expandedExerciseIDs.insert(entryID)
                } else {
                    expandedExerciseIDs.remove(entryID)
                }
            }
        )
    }

    private func affectedSubcategoryNames(for entry: ExerciseLogEntry) -> [String] {
        guard let primarySubcategoryID = entry.subcategoryID,
              let primarySubcategory = availableSubcategories.first(where: { $0.id == primarySubcategoryID }),
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
            guard let subcategory = availableSubcategories.first(where: { $0.id == id }),
                  subcategory.id != primarySubcategory.id,
                  subcategory.category?.resolvedWorkoutType == primaryWorkoutType else {
                return nil
            }
            return subcategory.name
        }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func deleteExercises(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    private func addExercise(from option: ExerciseQuickAddOption) {
        var entry = ExerciseLogEntry(name: option.name, subcategoryID: option.subcategoryID)
        ExerciseSessionActions.prefill(entry: &entry, workouts: workouts, exerciseTemplates: exerciseTemplates)
        if let lastMatch = entries.last(where: { $0.trimmedName.caseInsensitiveCompare(option.name) == .orderedSame }),
           entry.setEntries.isEmpty {
            entry.setEntries = lastMatch.setEntries.map {
                ExerciseSetEntry(reps: $0.reps, weight: $0.weight, isCompleted: false)
            }
            ExerciseSessionActions.syncLegacyMetrics(&entry)
        }
        entries.append(entry)
        expandedExerciseIDs.insert(entry.id)
    }

    private func saveExerciseTemplateIfNeeded(name: String, subcategoryID: UUID) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let subcategory = availableSubcategories.first(where: { $0.id == subcategoryID }) else {
            return
        }

        let exists = exerciseTemplates.contains {
            $0.subcategory?.id == subcategoryID &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedName) == .orderedSame
        }
        guard !exists else { return }

        let order = exerciseTemplates.filter { $0.subcategory?.id == subcategoryID }.count
        modelContext.insert(SubcategoryExercise(name: trimmedName, subcategory: subcategory, orderIndex: order))
        try? modelContext.save()
    }
}
