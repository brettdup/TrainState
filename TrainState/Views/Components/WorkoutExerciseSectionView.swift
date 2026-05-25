import SwiftUI
import SwiftData

struct WorkoutExerciseSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]

    @Binding var entries: [ExerciseLogEntry]

    let tintColor: Color
    let availableSubcategories: [WorkoutSubcategory]
    let quickAddOptions: [ExerciseQuickAddOption]
    let allowsReordering: Bool
    let onTap: (ExerciseLogEntry) -> Void

    @State private var showingExercisePicker = false

    var body: some View {
        Section {
            Button {
                showingExercisePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tintColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Exercises")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Search and select from your library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if entries.isEmpty {
                ContentUnavailableView(
                    "No Exercises Yet",
                    systemImage: "dumbbell",
                    description: Text("Tap “Add Exercises” to search and select from your library.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else if allowsReordering {
                ReorderableExerciseList(entries: $entries, onTap: onTap)
            } else {
                ForEach(entries) { entry in
                    Button {
                        onTap(entry)
                    } label: {
                        ExerciseCardView(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }

            if quickAddOptions.isEmpty {
                Text("Select workout subcategories to populate your exercise library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Exercises")
                Spacer()
                if allowsReordering && !entries.isEmpty {
                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
                    let entry = ExerciseLogEntry(name: name, subcategoryID: subcategoryID)
                    entries.append(entry)
                    onTap(entry)
                },
                tintColor: tintColor
            )
        }
    }

    private func addExercise(from option: ExerciseQuickAddOption) {
        var entry = ExerciseLogEntry(name: option.name, subcategoryID: option.subcategoryID)
        if let lastMatch = entries.last(where: { $0.trimmedName.caseInsensitiveCompare(option.name) == .orderedSame }) {
            entry.setEntries = lastMatch.setEntries
            entry.sets = lastMatch.effectiveSetCount
            entry.reps = lastMatch.effectiveReps
            entry.weight = lastMatch.effectiveWeight
        }
        entries.append(entry)
        onTap(entry)
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

private struct ReorderableExerciseList: View {
    @Binding var entries: [ExerciseLogEntry]
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
                        isDragging: draggingItem?.id == entry.id
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
}
