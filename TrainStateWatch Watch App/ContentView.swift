//
//  ContentView.swift
//  TrainStateWatch Watch App
//
//  Created by Brett du Plessis on 2026/02/17.
//

import SwiftUI
import HealthKit
import Combine

struct LoggedExercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: Int
    let weightKg: Double
    let notes: String
    let loggedAt: Date
}

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Double?
    @Published var activeEnergy: Double?
    @Published var errorMessage: String?
    @Published var exercises: [LoggedExercise] = []

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var sessionStartDate: Date?

    func startStrengthWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is unavailable."
            return
        }

        Task {
            do {
                try await requestAuthorization()
                try beginWorkoutSession()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func endWorkout() {
        guard let workoutSession, let workoutBuilder else {
            isRunning = false
            stopTimer()
            return
        }

        workoutSession.end()
        workoutBuilder.endCollection(withEnd: .now) { _, _ in
            workoutBuilder.finishWorkout { _, _ in }
        }

        isRunning = false
        stopTimer()
    }

    func addExercise(_ entry: LoggedExercise) {
        exercises.append(entry)
    }

    private func requestAuthorization() async throws {
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)

        var readTypes: Set<HKObjectType> = [workoutType]
        if let heartRateType { readTypes.insert(heartRateType) }
        if let activeEnergyType { readTypes.insert(activeEnergyType) }

        try await healthStore.requestAuthorization(toShare: [workoutType], read: readTypes)
    }

    private func beginWorkoutSession() throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        session.delegate = self
        builder.delegate = self

        let now = Date()
        session.startActivity(with: now)
        builder.beginCollection(withStart: now) { _, _ in }

        sessionStartDate = now
        workoutSession = session
        workoutBuilder = builder
        errorMessage = nil
        isRunning = true
        elapsedSeconds = 0
        exercises = []
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let sessionStartDate else { return }
            elapsedSeconds = max(Int(Date().timeIntervalSince(sessionStartDate)), 0)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            if toState == .ended {
                self.isRunning = false
                self.stopTimer()
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.isRunning = false
            self.stopTimer()
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

                if quantityType == HKObjectType.quantityType(forIdentifier: .heartRate) {
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit)
                }

                if quantityType == HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                    self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var workoutManager = WatchWorkoutManager()
    @State private var isShowingLogSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Live Workout") {
                    statRow(title: "Status", value: workoutManager.isRunning ? "Running" : "Idle")
                    statRow(title: "Duration", value: formattedDuration(workoutManager.elapsedSeconds))
                    statRow(title: "Heart Rate", value: workoutManager.heartRate.map { "\(Int($0)) bpm" } ?? "--")
                    statRow(title: "Energy", value: workoutManager.activeEnergy.map { "\(Int($0)) kcal" } ?? "--")
                }

                Section {
                    if workoutManager.isRunning {
                        Button("Log Exercise") {
                            isShowingLogSheet = true
                        }
                        .tint(.orange)

                        Button("End Workout", role: .destructive) {
                            workoutManager.endWorkout()
                        }
                    } else {
                        Button("Start Strength Workout") {
                            workoutManager.startStrengthWorkout()
                        }
                    }
                }

                if !workoutManager.exercises.isEmpty {
                    Section("Logged Exercises") {
                        ForEach(workoutManager.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.headline)
                                Text("\(exercise.sets)x\(exercise.reps) @ \(exercise.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("TrainState")
            .sheet(isPresented: $isShowingLogSheet) {
                LogExerciseSheet { exercise in
                    workoutManager.addExercise(exercise)
                }
            }
            .alert("Workout Error", isPresented: Binding(
                get: { workoutManager.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { workoutManager.errorMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(workoutManager.errorMessage ?? "")
            }
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct LogExerciseSheet: View {
    private static let presetExercises: [String] = [
        "Bench Press",
        "Back Squat",
        "Deadlift",
        "Overhead Press",
        "Barbell Row",
        "Pull-Up",
        "Incline Dumbbell Press",
        "Romanian Deadlift",
        "Leg Press",
        "Lateral Raise"
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise = "Bench Press"
    @State private var customExerciseName = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weightStep = 8
    @State private var notes = ""

    let onSave: (LoggedExercise) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(Self.presetExercises, id: \.self) { exercise in
                        Text(exercise).tag(exercise)
                    }
                    Text("Custom").tag("Custom")
                }

                if selectedExercise == "Custom" {
                    TextField("Custom Exercise", text: $customExerciseName)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("Sets", selection: $sets) {
                            ForEach(1...12, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 72)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("Reps", selection: $reps) {
                            ForEach(1...30, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 72)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("Weight", selection: $weightStep) {
                        ForEach(0...160, id: \.self) { step in
                            Text("\(Double(step) * 2.5, specifier: "%.1f") kg").tag(step)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 72)
                }
                TextField("Notes", text: $notes)
            }
            .navigationTitle("Log Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exerciseName = selectedExercise == "Custom"
                            ? customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                            : selectedExercise
                        let weightKg = Double(weightStep) * 2.5

                        onSave(
                            LoggedExercise(
                                name: exerciseName,
                                sets: sets,
                                reps: reps,
                                weightKg: weightKg,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                loggedAt: Date()
                            )
                        )
                        dismiss()
                    }
                    .disabled(selectedExercise == "Custom" && customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
