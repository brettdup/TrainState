//
//  ContentView.swift
//  TrainStateWatch Watch App
//
//  Created by Brett du Plessis on 2026/02/17.
//

import SwiftUI
import HealthKit
import Combine
import WatchConnectivity

struct LoggedExercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: Int
    let weightKg: Double
    let effortScore: Int
    let subcategoryID: UUID?
    let notes: String
    let loggedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: Int,
        weightKg: Double,
        effortScore: Int,
        subcategoryID: UUID?,
        notes: String,
        loggedAt: Date
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.effortScore = effortScore
        self.subcategoryID = subcategoryID
        self.notes = notes
        self.loggedAt = loggedAt
    }
}

struct WatchQuickLogExerciseOption: Identifiable, Hashable {
    let id: String
    let name: String
    let subcategoryID: UUID?
    let subcategoryName: String?
    let categoryName: String?

    init(
        name: String,
        id: String? = nil,
        subcategoryID: UUID? = nil,
        subcategoryName: String? = nil,
        categoryName: String? = nil
    ) {
        self.id = id ?? subcategoryID?.uuidString ?? name
        self.name = name
        self.subcategoryID = subcategoryID
        self.subcategoryName = subcategoryName
        self.categoryName = categoryName
    }

    init?(payload: [String: Any]) {
        guard let name = payload["name"] as? String else { return nil }

        let subcategoryID = (payload["subcategoryID"] as? String).flatMap(UUID.init(uuidString:))
        self.init(
            name: name,
            subcategoryID: subcategoryID,
            subcategoryName: payload["subcategoryName"] as? String,
            categoryName: payload["categoryName"] as? String
        )
    }

    static func payloads(from value: Any?) -> [WatchQuickLogExerciseOption] {
        guard let payloads = value as? [[String: Any]] else { return [] }
        return payloads.compactMap(WatchQuickLogExerciseOption.init(payload:))
    }
}

struct WatchQuickLogCategory: Identifiable, Hashable {
    let id: UUID
    let name: String
    let workoutName: String
    let options: [WatchQuickLogExerciseOption]

    init?(payload: [String: Any]) {
        guard let idString = payload["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = payload["name"] as? String else {
            return nil
        }

        let subcategoryPayloads = payload["subcategories"] as? [[String: Any]] ?? []
        self.id = id
        self.name = name
        self.workoutName = payload["workoutName"] as? String ?? "Workout"
        self.options = subcategoryPayloads.flatMap { subcategoryPayload -> [WatchQuickLogExerciseOption] in
            guard let subcategoryIDString = subcategoryPayload["id"] as? String,
                  let subcategoryID = UUID(uuidString: subcategoryIDString),
                  let subcategoryName = subcategoryPayload["name"] as? String else {
                return []
            }

            let exercisePayloads = subcategoryPayload["exercises"] as? [[String: Any]] ?? []
            let templateOptions = exercisePayloads.compactMap { exercisePayload -> WatchQuickLogExerciseOption? in
                guard let exerciseName = exercisePayload["name"] as? String else { return nil }
                let templateID = exercisePayload["id"] as? String ?? exerciseName
                return WatchQuickLogExerciseOption(
                    name: exerciseName,
                    id: "\(templateID)-\(subcategoryID.uuidString)",
                    subcategoryID: subcategoryID,
                    subcategoryName: subcategoryName,
                    categoryName: name
                )
            }

            if !templateOptions.isEmpty {
                return templateOptions
            }

            return [
                WatchQuickLogExerciseOption(
                    name: subcategoryName,
                    id: subcategoryID.uuidString,
                    subcategoryID: subcategoryID,
                    subcategoryName: subcategoryName,
                    categoryName: name
                )
            ]
        }
    }

    static func payloads(from value: Any?) -> [WatchQuickLogCategory] {
        guard let payloads = value as? [[String: Any]] else { return [] }
        return payloads.compactMap(WatchQuickLogCategory.init(payload:))
    }
}

struct WatchWeekWorkoutSummary: Identifiable {
    let id: UUID
    let title: String
    let startDate: Date
    let duration: TimeInterval
    let systemImage: String
    let categories: [WatchWorkoutCategorySummary]
    let subcategories: [WatchWorkoutSubcategorySummary]
    let exercises: [WatchWorkoutExerciseSummary]

    init(workout: HKWorkout) {
        self.id = workout.uuid
        self.title = workout.workoutActivityType.watchDisplayName
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.systemImage = workout.workoutActivityType.watchSystemImage
        self.categories = []
        self.subcategories = []
        self.exercises = []
    }

    init?(phonePayload: [String: Any]) {
        guard let idString = phonePayload["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = phonePayload["title"] as? String,
              let startTime = phonePayload["startDate"] as? TimeInterval,
              let duration = phonePayload["duration"] as? TimeInterval else {
            return nil
        }

        self.id = id
        self.title = title
        self.startDate = Date(timeIntervalSince1970: startTime)
        self.duration = duration
        self.systemImage = phonePayload["systemImage"] as? String ?? "figure.run"
        self.categories = WatchWorkoutCategorySummary.payloads(from: phonePayload["categories"])
        self.subcategories = WatchWorkoutSubcategorySummary.payloads(from: phonePayload["subcategories"])
        self.exercises = WatchWorkoutExerciseSummary.payloads(from: phonePayload["exercises"])
    }

    static func phonePayloads(from payload: [String: Any]) -> [WatchWeekWorkoutSummary]? {
        guard payload["event"] as? String == "phoneWeekSnapshot",
              let workoutPayloads = payload["workouts"] as? [[String: Any]] else {
            return nil
        }

        return workoutPayloads.compactMap(WatchWeekWorkoutSummary.init(phonePayload:))
    }

    static func quickLogOptions(from payload: [String: Any]) -> [WatchQuickLogExerciseOption] {
        WatchQuickLogExerciseOption.payloads(from: payload["quickLogExercises"])
    }

    static func quickLogCategories(from payload: [String: Any]) -> [WatchQuickLogCategory] {
        WatchQuickLogCategory.payloads(from: payload["quickLogCategories"])
    }
}

struct WatchWorkoutCategorySummary: Identifiable {
    let id: UUID
    let name: String

    init?(payload: [String: Any]) {
        guard let idString = payload["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = payload["name"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
    }

    static func payloads(from value: Any?) -> [WatchWorkoutCategorySummary] {
        guard let payloads = value as? [[String: Any]] else { return [] }
        return payloads.compactMap(WatchWorkoutCategorySummary.init(payload:))
    }
}

struct WatchWorkoutSubcategorySummary: Identifiable {
    let id: UUID
    let name: String
    let categoryName: String?

    init?(payload: [String: Any]) {
        guard let idString = payload["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = payload["name"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
        self.categoryName = payload["categoryName"] as? String
    }

    static func payloads(from value: Any?) -> [WatchWorkoutSubcategorySummary] {
        guard let payloads = value as? [[String: Any]] else { return [] }
        return payloads.compactMap(WatchWorkoutSubcategorySummary.init(payload:))
    }
}

struct WatchWorkoutExerciseSummary: Identifiable {
    let id: UUID
    let name: String
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let effortScore: Int?
    let notes: String?
    let subcategoryName: String?

    init?(payload: [String: Any]) {
        guard let idString = payload["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = payload["name"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
        self.sets = Self.intValue(payload["sets"])
        self.reps = Self.intValue(payload["reps"])
        self.weight = Self.doubleValue(payload["weight"])
        self.effortScore = Self.intValue(payload["effortScore"])
        self.notes = payload["notes"] as? String
        self.subcategoryName = payload["subcategoryName"] as? String
    }

    var setSummary: String {
        var parts: [String] = []
        if let sets, let reps {
            parts.append("\(sets)x\(reps)")
        } else if let sets {
            parts.append("\(sets) set\(sets == 1 ? "" : "s")")
        } else if let reps {
            parts.append("\(reps) reps")
        }
        if let weight {
            parts.append("\(weight.formatted(.number.precision(.fractionLength(0...1)))) kg")
        }
        if let effortScore {
            parts.append("\(effortScore)/10")
        }
        return parts.isEmpty ? "Logged" : parts.joined(separator: " - ")
    }

    static func payloads(from value: Any?) -> [WatchWorkoutExerciseSummary] {
        guard let payloads = value as? [[String: Any]] else { return [] }
        return payloads.compactMap(WatchWorkoutExerciseSummary.init(payload:))
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        return (value as? NSNumber)?.intValue
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        return (value as? NSNumber)?.doubleValue
    }
}

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Double?
    @Published var activeEnergy: Double?
    @Published var errorMessage: String?
    @Published var exercises: [LoggedExercise] = []
    @Published var weekWorkouts: [WatchWeekWorkoutSummary] = []
    @Published var quickLogOptions: [WatchQuickLogExerciseOption] = LogExerciseSheet.defaultExerciseOptions
    @Published var quickLogCategories: [WatchQuickLogCategory] = []
    @Published var isLoadingWeek = false

    private let healthStore = HKHealthStore()
    private let persistedQuickLogsKey = "watchPersistedQuickLogs"
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var sessionStartDate: Date?

    override init() {
        super.init()
        exercises = loadPersistedExercises()
        activateWatchConnectivity()
    }

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
        persistExercises()
        sendQuickLogToPhone(entry)
    }

    func loadCurrentWeek() {
        Task {
            await refresh()
        }
    }

    func refresh() async {
        guard !isLoadingWeek else { return }
        isLoadingWeek = true
        exercises = loadPersistedExercises()

        do {
            if let phoneWorkouts = try await requestPhoneWeekSnapshot() {
                weekWorkouts = phoneWorkouts
            } else if HKHealthStore.isHealthDataAvailable() {
                try await requestAuthorization()
                weekWorkouts = try await queryCurrentWeekWorkouts()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingWeek = false
    }

    private func activateWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func requestPhoneWeekSnapshot() async throws -> [WatchWeekWorkoutSummary]? {
        guard WCSession.isSupported() else { return nil }

        let session = WCSession.default
        updateQuickLogOptions(fromPhonePayload: session.applicationContext)
        if let contextWorkouts = workouts(fromPhonePayload: session.applicationContext), !contextWorkouts.isEmpty {
            return contextWorkouts
        }

        guard session.activationState == .activated, session.isReachable else {
            return nil
        }

        let reply: [String: Any] = try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                ["event": "requestPhoneWeekSnapshot"],
                replyHandler: { reply in
                    continuation.resume(returning: reply)
                },
                errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            )
        }

        updateQuickLogOptions(fromPhonePayload: reply)
        return WatchWeekWorkoutSummary.phonePayloads(from: reply)
    }

    nonisolated private func workouts(fromPhonePayload payload: [String: Any]) -> [WatchWeekWorkoutSummary]? {
        WatchWeekWorkoutSummary.phonePayloads(from: payload)
    }

    private func updateQuickLogOptions(fromPhonePayload payload: [String: Any]) {
        let categories = WatchWeekWorkoutSummary.quickLogCategories(from: payload)
        if !categories.isEmpty {
            quickLogCategories = categories
            quickLogOptions = categories.flatMap(\.options)
            return
        }

        let options = WatchWeekWorkoutSummary.quickLogOptions(from: payload)
        guard !options.isEmpty else { return }
        quickLogOptions = options
    }

    private func sendQuickLogToPhone(_ exercise: LoggedExercise) {
        guard WCSession.isSupported() else { return }

        var payload: [String: Any] = [
            "event": "watchQuickExerciseLog",
            "id": exercise.id.uuidString,
            "exerciseName": exercise.name,
            "loggedAt": exercise.loggedAt.timeIntervalSince1970,
            "sets": exercise.sets,
            "reps": exercise.reps,
            "weight": exercise.weightKg,
            "effortScore": exercise.effortScore,
            "source": "Apple Watch",
            "notes": exercise.notes
        ]
        if let subcategoryID = exercise.subcategoryID {
            payload["subcategoryID"] = subcategoryID.uuidString
        }

        let session = WCSession.default
        if session.activationState != .activated {
            session.activate()
        }

        if session.isReachable {
            session.sendMessage(
                payload,
                replyHandler: { _ in },
                errorHandler: { error in
                    print("[WatchWorkoutManager] Quick log message failed: \(error.localizedDescription)")
                    session.transferUserInfo(payload)
                }
            )
        } else {
            session.transferUserInfo(payload)
        }
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
        startTimer()
    }

    private func loadPersistedExercises() -> [LoggedExercise] {
        guard let data = UserDefaults.standard.data(forKey: persistedQuickLogsKey),
              let decoded = try? JSONDecoder().decode([LoggedExercise].self, from: data) else {
            return []
        }

        return decoded
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private func persistExercises() {
        let todaysExercises = exercises
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt > $1.loggedAt }

        exercises = todaysExercises

        guard let data = try? JSONEncoder().encode(todaysExercises) else { return }
        UserDefaults.standard.set(data, forKey: persistedQuickLogsKey)
    }

    private func queryCurrentWeekWorkouts() async throws -> [WatchWeekWorkoutSummary] {
        try await withCheckedThrowingContinuation { continuation in
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: Date(), options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 12,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts.map(WatchWeekWorkoutSummary.init))
            }
            healthStore.execute(query)
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let sessionStartDate = self.sessionStartDate else { return }
                self.elapsedSeconds = max(Int(Date().timeIntervalSince(sessionStartDate)), 0)
            }
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
                Section {
                    weekSummaryHeader
                }

                if !workoutManager.weekWorkouts.isEmpty {
                    Section("Recent") {
                        ForEach(workoutManager.weekWorkouts.prefix(4)) { workout in
                            NavigationLink {
                                WatchWorkoutDetailView(workout: workout)
                            } label: {
                                weekWorkoutRow(workout)
                            }
                        }
                    }
                }

                Section("Live") {
                    liveMetricGrid

                    if workoutManager.isRunning {
                        Button {
                            isShowingLogSheet = true
                        } label: {
                            Label("Quick Log", systemImage: "plus.circle.fill")
                        }
                        .tint(.orange)

                        Button("End Workout", role: .destructive) {
                            workoutManager.endWorkout()
                        }
                    } else {
                        Button {
                            isShowingLogSheet = true
                        } label: {
                            Label("Quick Log", systemImage: "plus.circle.fill")
                        }
                        .tint(.orange)

                        Button {
                            workoutManager.startStrengthWorkout()
                        } label: {
                            Label("Start Strength", systemImage: "play.fill")
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
            .navigationTitle("Exercise Pal")
            .task {
                workoutManager.loadCurrentWeek()
            }
            .refreshable {
                await workoutManager.refresh()
            }
            .sheet(isPresented: $isShowingLogSheet) {
                LogExerciseSheet(
                    categories: workoutManager.quickLogCategories,
                    exerciseOptions: workoutManager.quickLogOptions
                ) { exercise in
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

    private var weekSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("This Week", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                if workoutManager.isLoadingWeek {
                    ProgressView()
                } else {
                    Text("\(workoutManager.weekWorkouts.count)")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                weekMetric(value: "\(weeklyMinutes)", label: "min", systemImage: "clock.fill")
                weekMetric(value: "\(trainedDays)", label: "days", systemImage: "flame.fill")
            }
        }
        .padding(.vertical, 4)
    }

    private var liveMetricGrid: some View {
        VStack(spacing: 8) {
            HStack {
                watchMetric("Time", formattedDuration(workoutManager.elapsedSeconds), "timer")
                watchMetric("HR", workoutManager.heartRate.map { "\(Int($0))" } ?? "--", "heart.fill")
            }
            HStack {
                watchMetric("Energy", workoutManager.activeEnergy.map { "\(Int($0))" } ?? "--", "flame.fill")
                watchMetric("Sets", "\(workoutManager.exercises.count)", "list.bullet")
            }
        }
        .padding(.vertical, 4)
    }

    private func weekMetric(value: String, label: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func watchMetric(_ title: String, _ value: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekWorkoutRow(_ workout: WatchWeekWorkoutSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: workout.systemImage)
                .foregroundStyle(.orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(workout.startDate.formatted(date: .omitted, time: .shortened)) · \(formattedDuration(Int(workout.duration)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weeklyMinutes: Int {
        Int(workoutManager.weekWorkouts.reduce(0) { $0 + $1.duration } / 60)
    }

    private var trainedDays: Int {
        let calendar = Calendar.current
        return Set(workoutManager.weekWorkouts.map { calendar.startOfDay(for: $0.startDate) }).count
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

private struct WatchWorkoutDetailView: View {
    let workout: WatchWeekWorkoutSummary

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(workout.title, systemImage: workout.systemImage)
                        .font(.headline)
                    Text("\(workout.startDate.formatted(date: .abbreviated, time: .shortened)) - \(formattedDuration(Int(workout.duration)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            if !workout.categories.isEmpty {
                Section("Categories") {
                    ForEach(workout.categories) { category in
                        Label(category.name, systemImage: "folder.fill")
                    }
                }
            }

            if !workout.subcategories.isEmpty {
                Section("Trained") {
                    ForEach(workout.subcategories) { subcategory in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subcategory.name)
                                .font(.subheadline.weight(.semibold))
                            if let categoryName = subcategory.categoryName, !categoryName.isEmpty {
                                Text(categoryName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !workout.exercises.isEmpty {
                Section("Exercises") {
                    ForEach(workout.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                            Text(exercise.setSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let subcategoryName = exercise.subcategoryName, !subcategoryName.isEmpty {
                                Text(subcategoryName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let notes = exercise.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if workout.categories.isEmpty && workout.subcategories.isEmpty && workout.exercises.isEmpty {
                Section {
                    Text("No phone workout details yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Workout")
    }

    private func formattedDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchWorkoutManager] Activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.updateQuickLogOptions(fromPhonePayload: applicationContext)
            guard let workouts = self.workouts(fromPhonePayload: applicationContext) else { return }
            self.weekWorkouts = workouts
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.updateQuickLogOptions(fromPhonePayload: userInfo)
            guard let workouts = self.workouts(fromPhonePayload: userInfo) else { return }
            self.weekWorkouts = workouts
        }
    }
}

private struct LogExerciseSheet: View {
    static let defaultExerciseOptions: [WatchQuickLogExerciseOption] = [
        WatchQuickLogExerciseOption(name: "Bench Press"),
        WatchQuickLogExerciseOption(name: "Back Squat"),
        WatchQuickLogExerciseOption(name: "Deadlift"),
        WatchQuickLogExerciseOption(name: "Overhead Press"),
        WatchQuickLogExerciseOption(name: "Barbell Row"),
        WatchQuickLogExerciseOption(name: "Pull-Up"),
        WatchQuickLogExerciseOption(name: "Incline Dumbbell Press"),
        WatchQuickLogExerciseOption(name: "Romanian Deadlift"),
        WatchQuickLogExerciseOption(name: "Leg Press"),
        WatchQuickLogExerciseOption(name: "Lateral Raise")
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkoutName: String
    @State private var selectedCategoryID: UUID?
    @State private var selectedExerciseID: String
    @State private var selectedExerciseName: String
    @State private var customExerciseName = ""
    @State private var sets = 1
    @State private var reps = 10
    @State private var weightStep = 8
    @State private var effort = 7

    private let categories: [WatchQuickLogCategory]
    private let exerciseOptions: [WatchQuickLogExerciseOption]
    let onSave: (LoggedExercise) -> Void

    init(
        categories: [WatchQuickLogCategory],
        exerciseOptions: [WatchQuickLogExerciseOption],
        onSave: @escaping (LoggedExercise) -> Void
    ) {
        let categoryOptions = categories.flatMap(\.options)
        let options = categoryOptions.isEmpty
            ? (exerciseOptions.isEmpty ? Self.defaultExerciseOptions : exerciseOptions)
            : categoryOptions
        self.categories = categories
        self.exerciseOptions = options
        self.onSave = onSave
        let firstWorkoutName = categories.first?.workoutName ?? "Workout"
        let firstCategoryID = categories.first { $0.workoutName == firstWorkoutName }?.id
        let firstOption = categories
            .first { $0.id == firstCategoryID }?
            .options
            .first ?? options.first
        _selectedWorkoutName = State(initialValue: firstWorkoutName)
        _selectedCategoryID = State(initialValue: firstCategoryID)
        _selectedExerciseID = State(initialValue: firstOption?.id ?? "Custom")
        _selectedExerciseName = State(initialValue: firstOption?.name ?? "Custom")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Log") {
                    NavigationLink {
                        WatchQuickLogWorkoutPicker(
                            workoutNames: workoutNames,
                            selectedWorkoutName: $selectedWorkoutName,
                            onSelect: { workoutName in
                                selectedWorkoutName = workoutName
                                selectFirstCategoryAndExercise(for: workoutName)
                            }
                        )
                    } label: {
                        summaryRow(title: "Workout", value: selectedWorkoutName)
                    }

                    NavigationLink {
                        WatchQuickLogCategoryPicker(
                            categories: categoriesForSelectedWorkout,
                            selectedCategoryID: $selectedCategoryID,
                            onSelect: { category in
                                selectedCategoryID = category.id
                                selectFirstExercise(for: category)
                            }
                        )
                    } label: {
                        summaryRow(title: "Category", value: selectedCategoryName)
                    }

                    NavigationLink {
                        WatchQuickLogExercisePicker(
                            options: exerciseOptionsForSelectedCategory,
                            selectedExerciseID: $selectedExerciseID,
                            selectedExerciseName: $selectedExerciseName,
                            customExerciseName: $customExerciseName
                        )
                    } label: {
                        summaryRow(title: "Exercise", value: chosenExerciseName.isEmpty ? "Choose" : chosenExerciseName)
                    }
                }

                Section("Set") {
                    valueNavigationRow(title: "Sets", value: "\(sets)", binding: $sets, range: 1...12)
                    valueNavigationRow(title: "Reps", value: "\(reps)", binding: $reps, range: 1...40)
                    valueNavigationRow(title: "Effort", value: "\(effort)/10", binding: $effort, range: 1...10, suffix: "/10")
                }

                Section("Load") {
                    valueNavigationRow(
                        title: "Weight",
                        value: "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg",
                        binding: $weightStep,
                        range: 0...160,
                        displayValue: "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
                    )
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Label(saveTitle, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                    }
                    .disabled(isSaveDisabled)
                    .tint(.orange)
                }
            }
            .navigationTitle("Quick Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var selectedExerciseOption: WatchQuickLogExerciseOption? {
        exerciseOptionsForSelectedCategory.first { $0.id == selectedExerciseID }
    }

    private var selectedAttachOption: WatchQuickLogExerciseOption? {
        if selectedExerciseName == "Custom" {
            return exerciseOptionsForSelectedCategory.first
        }
        return selectedExerciseOption
    }

    private var workoutNames: [String] {
        var seenNames = Set<String>()
        return categories.compactMap { category in
            guard !seenNames.contains(category.workoutName) else { return nil }
            seenNames.insert(category.workoutName)
            return category.workoutName
        }
    }

    private var categoriesForSelectedWorkout: [WatchQuickLogCategory] {
        categories.filter { $0.workoutName == selectedWorkoutName }
    }

    private var selectedCategory: WatchQuickLogCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var selectedCategoryName: String {
        selectedCategory?.name ?? "Choose"
    }

    private var exerciseOptionsForSelectedCategory: [WatchQuickLogExerciseOption] {
        selectedCategory?.options ?? exerciseOptions
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var isSaveDisabled: Bool {
        if selectedExerciseName == "Custom" {
            return customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedAttachOption == nil
        }
        return selectedExerciseOption == nil
    }

    private var chosenExerciseName: String {
        if selectedExerciseName == "Custom" {
            return customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedExerciseName
    }

    private var weightKg: Double {
        Double(weightStep) * 2.5
    }

    private var saveTitle: String {
        let name = chosenExerciseName.isEmpty ? "Set" : chosenExerciseName
        return "Save \(sets)x\(reps) \(name)"
    }

    private var quickLogNote: String {
        "Effort \(effort)/10"
    }

    private func save() {
        let selectedOption = selectedAttachOption
        onSave(
            LoggedExercise(
                name: chosenExerciseName,
                sets: sets,
                reps: reps,
                weightKg: weightKg,
                effortScore: effort,
                subcategoryID: selectedOption?.subcategoryID,
                notes: quickLogNote,
                loggedAt: Date()
            )
        )
        dismiss()
    }

    private func selectFirstCategoryAndExercise(for workoutName: String) {
        guard let category = categories.first(where: { $0.workoutName == workoutName }) else {
            selectedCategoryID = nil
            selectedExerciseID = "Custom"
            selectedExerciseName = "Custom"
            return
        }
        selectedCategoryID = category.id
        selectFirstExercise(for: category)
    }

    private func selectFirstExercise(for category: WatchQuickLogCategory) {
        guard let option = category.options.first else {
            selectedExerciseID = "Custom"
            selectedExerciseName = "Custom"
            return
        }
        selectedExerciseID = option.id
        selectedExerciseName = option.name
        customExerciseName = ""
    }

    private func valueNavigationRow(
        title: String,
        value: String,
        binding: Binding<Int>,
        range: ClosedRange<Int>,
        suffix: String = "",
        displayValue: String? = nil
    ) -> some View {
        NavigationLink {
            WatchQuickLogValueEditor(
                title: title,
                value: binding,
                range: range,
                suffix: suffix,
                displayValue: displayValue
            )
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct WatchQuickLogWorkoutPicker: View {
    let workoutNames: [String]
    @Binding var selectedWorkoutName: String
    let onSelect: (String) -> Void

    var body: some View {
        List {
            ForEach(workoutNames, id: \.self) { workoutName in
                Button {
                    onSelect(workoutName)
                } label: {
                    pickerRow(title: workoutName, isSelected: selectedWorkoutName == workoutName)
                }
            }
        }
        .navigationTitle("Workout")
    }
}

private struct WatchQuickLogCategoryPicker: View {
    let categories: [WatchQuickLogCategory]
    @Binding var selectedCategoryID: UUID?
    let onSelect: (WatchQuickLogCategory) -> Void

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    onSelect(category)
                } label: {
                    pickerRow(title: category.name, isSelected: selectedCategoryID == category.id)
                }
            }
        }
        .navigationTitle("Category")
    }
}

private struct WatchQuickLogExercisePicker: View {
    let options: [WatchQuickLogExerciseOption]
    @Binding var selectedExerciseID: String
    @Binding var selectedExerciseName: String
    @Binding var customExerciseName: String

    var body: some View {
        List {
            ForEach(options) { option in
                Button {
                    selectedExerciseID = option.id
                    selectedExerciseName = option.name
                    customExerciseName = ""
                } label: {
                    pickerRow(title: option.name, isSelected: selectedExerciseID == option.id)
                }
            }

            Button {
                selectedExerciseID = "Custom"
                selectedExerciseName = "Custom"
            } label: {
                pickerRow(title: "Custom", isSelected: selectedExerciseName == "Custom", systemImage: "square.and.pencil")
            }

            if selectedExerciseName == "Custom" {
                TextField("Exercise", text: $customExerciseName)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle("Exercise")
    }
}

private func pickerRow(title: String, isSelected: Bool, systemImage: String? = nil) -> some View {
    HStack {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        Spacer()
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}

private struct WatchQuickLogValueEditor: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    let displayValue: String?

    var body: some View {
        VStack(spacing: 14) {
            Text(currentValue)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            HStack(spacing: 16) {
                Button {
                    value = max(value - 1, range.lowerBound)
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.bold))
                }
                .disabled(value <= range.lowerBound)

                Button {
                    value = min(value + 1, range.upperBound)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(.vertical, 8)
        .navigationTitle(title)
    }

    private var currentValue: String {
        displayValue ?? "\(value)\(suffix)"
    }
}

private extension HKWorkoutActivityType {
    var watchDisplayName: String {
        switch self {
        case .traditionalStrengthTraining:
            return "Strength"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .running:
            return "Run"
        case .walking:
            return "Walk"
        case .cycling:
            return "Ride"
        case .swimming:
            return "Swim"
        case .yoga:
            return "Yoga"
        case .highIntensityIntervalTraining:
            return "HIIT"
        default:
            return "Workout"
        }
    }

    var watchSystemImage: String {
        switch self {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "dumbbell.fill"
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        case .yoga:
            return "figure.mind.and.body"
        default:
            return "figure.run"
        }
    }
}

#Preview {
    ContentView()
}
