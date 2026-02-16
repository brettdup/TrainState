import SwiftUI

/// Shared exercise card component used across EditWorkout, AddWorkout, LiveStrengthSession, and WorkoutDetail views.
struct ExerciseCardView: View {
    @Environment(\.colorScheme) private var environmentColorScheme
    let name: String
    let setDetails: [String]
    let subcategoryName: String?
    var showDragHandle: Bool = false
    var showChevron: Bool = true
    var isDragging: Bool = false
    var colorScheme: ColorScheme? = nil

    private var effectiveColorScheme: ColorScheme {
        colorScheme ?? environmentColorScheme
    }

    private var iconColor: Color {
        ExerciseIconMapper.iconColor(for: name)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Drag handle (optional)
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)
            }

            // Exercise icon in rounded container
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                Image(systemName: ExerciseIconMapper.icon(for: name))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 36, height: 36)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Header row with name and subcategory
                VStack(alignment: .leading, spacing: 2) {
                    Text(name.isEmpty ? "Unnamed exercise" : name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subcategoryName, !subcategoryName.isEmpty {
                        Text(subcategoryName.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                }

                // Set details with improved styling
                if !setDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(setDetails.enumerated()), id: \.offset) { index, detail in
                            HStack(spacing: 6) {
                                // Completion indicator
                                Circle()
                                    .fill(detail.contains("Done") ? Color.green : Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: 6)

                                Text(formatSetDetail(detail))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(detail.contains("Done") ? .primary : .secondary)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            // Chevron (optional)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(effectiveColorScheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    iconColor.opacity(0.2),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: iconColor.opacity(isDragging ? 0.2 : 0.08),
            radius: isDragging ? 12 : 4,
            x: 0,
            y: isDragging ? 6 : 2
        )
        .opacity(isDragging ? 0.9 : 1.0)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }

    /// Format set detail text - keep "Set X:" but remove "Done - "
    private func formatSetDetail(_ detail: String) -> String {
        // Remove "Done - " if present but keep "Set X:"
        return detail.replacingOccurrences(of: "Done - ", with: "")
    }
}

// MARK: - Convenience initializers

extension ExerciseCardView {
    /// Initialize from an ExerciseLogEntry (for Add/Edit/Live views)
    init(entry: ExerciseLogEntry, subcategoryName: String? = nil, showDragHandle: Bool = false, showChevron: Bool = true, isDragging: Bool = false, colorScheme: ColorScheme? = nil) {
        self.name = entry.trimmedName
        self.setDetails = entry.setSummaryLines
        self.subcategoryName = subcategoryName
        self.showDragHandle = showDragHandle
        self.showChevron = showChevron
        self.isDragging = isDragging
        self.colorScheme = colorScheme
    }

    /// Initialize from a WorkoutExercise (for WorkoutDetail view)
    init(exercise: WorkoutExercise, showChevron: Bool = true, colorScheme: ColorScheme? = nil) {
        self.name = exercise.name
        self.subcategoryName = exercise.subcategory?.name
        self.showDragHandle = false
        self.showChevron = showChevron
        self.isDragging = false
        self.colorScheme = colorScheme

        // Parse set details from notes (lines starting with "Set ")
        var parsedSetDetails: [String] = []
        if let notes = exercise.notes, !notes.isEmpty {
            parsedSetDetails = notes
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.hasPrefix("Set ") }
        }

        // If no per-set details found, generate per-set lines from sets/reps/weight
        if parsedSetDetails.isEmpty {
            let setCount = exercise.sets ?? 0
            let reps = exercise.reps ?? 0
            let weight = exercise.weight ?? 0

            if setCount > 0 && (reps > 0 || weight > 0) {
                // Generate individual set lines
                for i in 1...setCount {
                    var setLine = "Set \(i): "
                    if reps > 0 && weight > 0 {
                        setLine += "\(reps) reps @ \(ExerciseLogEntry.displayWeight(weight)) kg"
                    } else if reps > 0 {
                        setLine += "\(reps) reps"
                    } else if weight > 0 {
                        setLine += "\(ExerciseLogEntry.displayWeight(weight)) kg"
                    }
                    parsedSetDetails.append(setLine)
                }
            }
        }

        self.setDetails = parsedSetDetails
    }
}

#Preview("Light Mode") {
    ScrollView {
        VStack(spacing: 12) {
            ExerciseCardView(
                name: "Bench Press",
                setDetails: [
                    "Set 1: Done - 8 reps @ 80 kg",
                    "Set 2: Done - 8 reps @ 80 kg",
                    "Set 3: 8 reps @ 80 kg"
                ],
                subcategoryName: "Chest",
                showDragHandle: true,
                colorScheme: .light
            )

            ExerciseCardView(
                name: "Back Squat",
                setDetails: [
                    "Set 1: Done - 5 reps @ 100 kg",
                    "Set 2: Done - 5 reps @ 100 kg",
                    "Set 3: 5 reps @ 100 kg"
                ],
                subcategoryName: "Legs",
                colorScheme: .light
            )

            ExerciseCardView(
                name: "Pull-ups",
                setDetails: [
                    "Set 1: Done - 10 reps @ 0 kg",
                    "Set 2: 8 reps @ 0 kg"
                ],
                subcategoryName: "Back",
                colorScheme: .light
            )

            ExerciseCardView(
                name: "Deadlift",
                setDetails: [],
                subcategoryName: "Full Body",
                isDragging: true,
                colorScheme: .light
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    ScrollView {
        VStack(spacing: 12) {
            ExerciseCardView(
                name: "Bench Press",
                setDetails: [
                    "Set 1: Done - 8 reps @ 80 kg",
                    "Set 2: Done - 8 reps @ 80 kg",
                    "Set 3: 8 reps @ 80 kg"
                ],
                subcategoryName: "Chest",
                showDragHandle: true,
                colorScheme: .dark
            )

            ExerciseCardView(
                name: "Back Squat",
                setDetails: [
                    "Set 1: Done - 5 reps @ 100 kg",
                    "Set 2: 5 reps @ 100 kg"
                ],
                subcategoryName: "Legs",
                colorScheme: .dark
            )

            ExerciseCardView(
                name: "Overhead Press",
                setDetails: [],
                subcategoryName: nil,
                colorScheme: .dark
            )
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
