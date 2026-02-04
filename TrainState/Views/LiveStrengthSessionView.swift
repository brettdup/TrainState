import SwiftUI

struct LiveStrengthSessionView: View {
    @Environment(\.dismiss) private var dismiss

    let typeTintColor: Color
    let availableSubcategories: [WorkoutSubcategory]
    let quickAddOptions: [ExerciseQuickAddOption]
    let onFinish: ([ExerciseLogEntry], Date, TimeInterval) -> Void
    let onCancel: ([ExerciseLogEntry]) -> Void

    @State private var entries: [ExerciseLogEntry]
    @State private var sessionStart: Date
    @State private var now: Date = Date()
    @State private var showCancelConfirmation = false
    @State private var showExerciseLinkAlert = false
    @State private var activeExerciseSelection: ExerciseEditorSelection?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        typeTintColor: Color,
        availableSubcategories: [WorkoutSubcategory],
        quickAddOptions: [ExerciseQuickAddOption],
        initialEntries: [ExerciseLogEntry],
        onFinish: @escaping ([ExerciseLogEntry], Date, TimeInterval) -> Void,
        onCancel: @escaping ([ExerciseLogEntry]) -> Void
    ) {
        self.typeTintColor = typeTintColor
        self.availableSubcategories = availableSubcategories
        self.quickAddOptions = quickAddOptions
        self.onFinish = onFinish
        self.onCancel = onCancel

        let seededEntries = initialEntries
        _entries = State(initialValue: seededEntries)
        _sessionStart = State(initialValue: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    timerCard
                    exercisesCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("Live Strength")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showCancelConfirmation = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish & Save") {
                        finishSession()
                    }
                    .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(true)
            .confirmationDialog("Discard this live session?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                Button("Discard Session", role: .destructive) {
                    onCancel(entries)
                    dismiss()
                }
                Button("Keep Session", role: .cancel) { }
            } message: {
                Text("Your logged exercises will be kept in draft if you discard.")
            }
            .alert("Link Exercises to Subcategories", isPresented: $showExerciseLinkAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Each exercise must be linked to a subcategory before finishing.")
            }
            .sheet(item: $activeExerciseSelection) { selection in
                if let index = entries.firstIndex(where: { $0.id == selection.id }) {
                    ExerciseEditorSheetView(
                        entry: $entries[index],
                        availableSubcategories: availableSubcategories,
                        availableOptions: quickAddOptions,
                        onDelete: {
                            entries.removeAll { $0.id == selection.id }
                        }
                    )
                } else {
                    EmptyView()
                }
            }
        }
        .onReceive(timer) { timestamp in
            now = timestamp
        }
        .onChange(of: activeExerciseSelection) { _, newValue in
            if newValue == nil {
                entries.removeAll { $0.isEmpty }
            }
        }
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Running")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formattedDuration(elapsedDuration))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("Started \(sessionStart.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 24, isInteractive: false)
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises")
                    .font(.headline)
                Spacer()
                Button {
                    addAndEditNewExercise()
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(typeTintColor.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                ForEach(entries) { entry in
                    Button {
                        activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.trimmedName.isEmpty ? "Unnamed exercise" : entry.trimmedName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if let summary = exerciseSummary(for: entry) {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if quickAddOptions.isEmpty {
                Text("Select workout subcategories to unlock quick-add exercise chips.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 24, isInteractive: true)
    }

    private var elapsedDuration: TimeInterval {
        max(now.timeIntervalSince(sessionStart), 0)
    }

    private func finishSession() {
        guard !hasUnlinkedExercises(entries) else {
            showExerciseLinkAlert = true
            return
        }
        onFinish(entries, sessionStart, elapsedDuration)
        dismiss()
    }

    private func hasUnlinkedExercises(_ entries: [ExerciseLogEntry]) -> Bool {
        entries.contains { !$0.trimmedName.isEmpty && $0.subcategoryID == nil }
    }

    private func defaultExerciseEntry() -> ExerciseLogEntry {
        guard let firstSubcategory = availableSubcategories.first else { return ExerciseLogEntry() }
        let names = quickAddOptions.filter { $0.subcategoryID == firstSubcategory.id }.map(\.name)
        return ExerciseLogEntry(
            name: names.first ?? "",
            subcategoryID: firstSubcategory.id
        )
    }

    private func addAndEditNewExercise() {
        let newEntry = defaultExerciseEntry()
        entries.append(newEntry)
        activeExerciseSelection = ExerciseEditorSelection(id: newEntry.id)
    }

    private func exerciseSummary(for entry: ExerciseLogEntry) -> String? {
        let setsText = entry.sets.map { "\($0)x" }
        let repsText = entry.reps.map { "\($0)" }
        let weightText: String? = {
            guard let w = entry.weight, w > 0 else { return nil }
            return String(format: "%.1f kg", w)
        }()

        let primary = [setsText, repsText].compactMap { $0 }.joined(separator: " ")
        let withWeight: String
        if let weightText {
            withWeight = primary.isEmpty ? weightText : "\(primary) · \(weightText)"
        } else {
            withWeight = primary
        }

        return withWeight.isEmpty ? nil : withWeight
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

#Preview {
    let strength = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
    let chest = WorkoutSubcategory(name: "Chest", category: strength)
    let legs = WorkoutSubcategory(name: "Legs", category: strength)

    return LiveStrengthSessionView(
        typeTintColor: .green,
        availableSubcategories: [chest, legs],
        quickAddOptions: [
            ExerciseQuickAddOption(name: "Bench Press", subcategoryID: chest.id),
            ExerciseQuickAddOption(name: "Back Squat", subcategoryID: legs.id)
        ],
        initialEntries: [
            ExerciseLogEntry(name: "Bench Press", sets: 4, reps: 8, weight: 80, subcategoryID: chest.id)
        ],
        onFinish: { _, _, _ in },
        onCancel: { _ in }
    )
}
