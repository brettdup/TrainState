import SwiftUI
import SwiftData

struct WorkoutSessionConfiguration {
    var isTimerRunning: Bool
    var sessionStart: Date
    var title: String = "Workout"
}

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("measurementSystem") private var measurementSystemRaw = MeasurementSystem.metric.rawValue
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]

    let typeTintColor: Color
    let availableSubcategories: [WorkoutSubcategory]
    let quickAddOptions: [ExerciseQuickAddOption]
    let configuration: WorkoutSessionConfiguration
    let onFinish: ([ExerciseLogEntry], Date, TimeInterval) -> Void
    let onCancel: ([ExerciseLogEntry]) -> Void

    @AppStorage("restTimerEnabled") private var restTimerEnabled = false
    @AppStorage("restTimerDurationSeconds") private var restTimerDurationSeconds = 90
    @State private var entries: [ExerciseLogEntry]
    @State private var sessionStart: Date
    @State private var isTimerRunning: Bool
    @State private var now: Date = Date()
    @State private var showCancelConfirmation = false
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var didStartLiveActivity = false
    @State private var restSecondsRemaining: Int?
    @State private var expandedExerciseIDs: Set<UUID> = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        typeTintColor: Color,
        availableSubcategories: [WorkoutSubcategory],
        quickAddOptions: [ExerciseQuickAddOption],
        initialEntries: [ExerciseLogEntry],
        configuration: WorkoutSessionConfiguration,
        onFinish: @escaping ([ExerciseLogEntry], Date, TimeInterval) -> Void,
        onCancel: @escaping ([ExerciseLogEntry]) -> Void
    ) {
        self.typeTintColor = typeTintColor
        self.availableSubcategories = availableSubcategories
        self.quickAddOptions = quickAddOptions
        self.configuration = configuration
        self.onFinish = onFinish
        self.onCancel = onCancel
        _entries = State(initialValue: initialEntries)
        _sessionStart = State(initialValue: configuration.sessionStart)
        _isTimerRunning = State(initialValue: configuration.isTimerRunning)
    }

    private var measurementSystem: MeasurementSystem {
        MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric
    }

    var body: some View {
        NavigationStack {
            List {
                sessionSection

                if let restSecondsRemaining {
                    Section {
                        restTimerRow(seconds: restSecondsRemaining)
                    }
                }

                exercisesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(configuration.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        persistDraft()
                        showCancelConfirmation = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        finishSession()
                    }
                    .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(true)
            .confirmationDialog("Leave this workout?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                Button("Keep Draft", role: .cancel) {
                    persistDraft()
                    onCancel(entries)
                    dismiss()
                }
                Button("Discard", role: .destructive) {
                    if isTimerRunning {
                        WorkoutLiveActivityManager.shared.end()
                    }
                    WorkoutSessionDraftStore.clear()
                    onCancel(entries)
                    dismiss()
                }
            } message: {
                Text("Your exercises are saved as a draft so you can continue later.")
            }
            .sheet(item: $activeExerciseSelection) { selection in
                if let index = entries.firstIndex(where: { $0.id == selection.id }) {
                    ExerciseEditorSheetView(
                        entry: $entries[index],
                        availableSubcategories: availableSubcategories,
                        availableOptions: quickAddOptions,
                        onDelete: {
                            entries.removeAll { $0.id == selection.id }
                        },
                        scope: .metadataOnly
                    )
                } else {
                    EmptyView()
                }
            }
        }
        .onReceive(timer) { timestamp in
            now = timestamp
            tickRestTimer()
        }
        .onAppear {
            startLiveActivityIfNeeded()
            persistDraft()
        }
        .onChange(of: entries) { _, _ in
            updateLiveActivity()
            persistDraft()
        }
        .onChange(of: activeExerciseSelection) { _, newValue in
            if newValue == nil {
                DispatchQueue.main.async {
                    entries.removeAll { $0.isEmpty }
                }
            }
        }
    }

    private var exercisesSection: some View {
        WorkoutExerciseSectionView(
            entries: $entries,
            tintColor: typeTintColor,
            availableSubcategories: availableSubcategories,
            quickAddOptions: quickAddOptions,
            workouts: workouts,
            exerciseTemplates: exerciseTemplates,
            measurementSystem: measurementSystem,
            restTimerEnabled: restTimerEnabled,
            restDurationSeconds: restTimerDurationSeconds,
            allowsReordering: true,
            expandedExerciseIDs: $expandedExerciseIDs,
            onEditMetadata: { entry in
                activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
            },
            onStartRest: {
                restSecondsRemaining = max(restTimerDurationSeconds, 15)
            }
        )
    }

    private var sessionSection: some View {
        Section {
            if isTimerRunning {
                LabeledContent("Elapsed") {
                    Text(formattedDuration(elapsedDuration))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(typeTintColor)
                }
            }

            Toggle("Track elapsed time", isOn: $isTimerRunning)
                .onChange(of: isTimerRunning) { _, running in
                    if running {
                        sessionStart = Date()
                        startLiveActivityIfNeeded()
                    } else {
                        WorkoutLiveActivityManager.shared.end()
                        didStartLiveActivity = false
                    }
                }

            if isTimerRunning {
                LabeledContent("Started") {
                    Text(sessionStart.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Session")
        } footer: {
            if !isTimerRunning {
                Text("Turn on the timer when you want elapsed time tracked during this workout.")
            }
        }
    }

    private func restTimerRow(seconds: Int) -> some View {
        LabeledContent {
            Button("Skip") {
                restSecondsRemaining = nil
            }
            .buttonStyle(.borderless)
        } label: {
            Label("Rest", systemImage: "timer")
        }
        .badge(seconds)
    }

    private var elapsedDuration: TimeInterval {
        guard isTimerRunning else { return 0 }
        return max(now.timeIntervalSince(sessionStart), 0)
    }

    private func finishSession() {
        let duration = isTimerRunning ? elapsedDuration : 0
        WorkoutSessionDraftStore.clear()
        if isTimerRunning {
            WorkoutLiveActivityManager.shared.end()
        }
        onFinish(entries, sessionStart, duration)
        dismiss()
    }

    private func persistDraft() {
        let draft = WorkoutSessionDraft(
            entries: entries,
            sessionStart: sessionStart,
            isTimerRunning: isTimerRunning,
            updatedAt: Date()
        )
        WorkoutSessionDraftStore.save(draft)
    }

    private func startLiveActivityIfNeeded() {
        guard isTimerRunning, !didStartLiveActivity else { return }
        didStartLiveActivity = true
        WorkoutLiveActivityManager.shared.start(
            workoutName: configuration.title,
            startedAt: sessionStart,
            exerciseCount: loggedExerciseCount,
            currentExercise: activeExerciseName
        )
    }

    private func updateLiveActivity() {
        guard isTimerRunning, didStartLiveActivity else { return }
        WorkoutLiveActivityManager.shared.update(
            elapsedSeconds: Int(elapsedDuration),
            exerciseCount: loggedExerciseCount,
            currentExercise: activeExerciseName
        )
    }

    private func tickRestTimer() {
        guard var remaining = restSecondsRemaining else { return }
        remaining -= 1
        if remaining <= 0 {
            restSecondsRemaining = nil
            HapticManager.lightImpact()
        } else {
            restSecondsRemaining = remaining
        }
    }

    private var loggedExerciseCount: Int {
        entries.filter { !$0.trimmedName.isEmpty }.count
    }

    private var activeExerciseName: String {
        entries.last(where: { !$0.trimmedName.isEmpty })?.trimmedName ?? "Logging sets"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

typealias LiveStrengthSessionView = WorkoutSessionView

extension WorkoutSessionView {
    init(
        typeTintColor: Color,
        availableSubcategories: [WorkoutSubcategory],
        quickAddOptions: [ExerciseQuickAddOption],
        initialEntries: [ExerciseLogEntry],
        onFinish: @escaping ([ExerciseLogEntry], Date, TimeInterval) -> Void,
        onCancel: @escaping ([ExerciseLogEntry]) -> Void
    ) {
        self.init(
            typeTintColor: typeTintColor,
            availableSubcategories: availableSubcategories,
            quickAddOptions: quickAddOptions,
            initialEntries: initialEntries,
            configuration: WorkoutSessionConfiguration(
                isTimerRunning: true,
                sessionStart: Date(),
                title: "Workout"
            ),
            onFinish: onFinish,
            onCancel: onCancel
        )
    }
}
