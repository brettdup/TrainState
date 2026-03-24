import SwiftUI

struct WorkoutExerciseSectionView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var entries: [ExerciseLogEntry]

    let tintColor: Color
    let availableSubcategories: [WorkoutSubcategory]
    let quickAddOptions: [ExerciseQuickAddOption]
    let allowsReordering: Bool
    let onTap: (ExerciseLogEntry) -> Void

    @State private var showingExercisePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if allowsReordering && !entries.isEmpty {
                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

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
                        Text("Search and select from your library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No exercises yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap \"Add Exercises\" to search and select from your library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if allowsReordering {
                ReorderableExerciseList(
                    entries: $entries,
                    colorScheme: colorScheme,
                    onTap: onTap
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(entries) { entry in
                        Button {
                            onTap(entry)
                        } label: {
                            ExerciseCardView(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if quickAddOptions.isEmpty {
                Text("Select workout subcategories to populate your exercise library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground)
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
                    let entry = ExerciseLogEntry(name: name, subcategoryID: subcategoryID)
                    entries.append(entry)
                    onTap(entry)
                },
                tintColor: tintColor
            )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 32)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.72), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 5, x: 0, y: 2)
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
}

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
}
