import Foundation
import SwiftData
import WatchConnectivity

@MainActor
final class WatchHealthKitSyncBridge: NSObject {
    static let shared = WatchHealthKitSyncBridge()

    private let importer = HealthKitRecentWorkoutImporter()
    private var modelContainer: ModelContainer?
    private var syncTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func start(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        updateWeekSnapshotContext()
    }

    private func scheduleImport(reason: String) {
        guard let modelContainer else { return }
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }

        syncTask?.cancel()
        syncTask = Task { @MainActor in
            do {
                let importedCount = try await importer.importNewAnchoredWorkouts(
                    into: modelContainer.mainContext,
                    initialLookbackDays: 14
                )
                if importedCount > 0 {
                    print("[WatchHealthKitSync] Imported \(importedCount) workout(s) after \(reason).")
                }
                attachPendingQuickExerciseLogsIfPossible()
                updateWeekSnapshotContext()
            } catch {
                print("[WatchHealthKitSync] Import failed after \(reason): \(error.localizedDescription)")
            }
        }
    }

    private func updateWeekSnapshotContext() {
        guard WCSession.isSupported(), let payload = makeWeekSnapshotPayload() else { return }

        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            print("[WatchHealthKitSync] Week snapshot context failed: \(error.localizedDescription)")
        }
    }

    private func makeWeekSnapshotPayload() -> [String: Any]? {
        guard let modelContainer else { return nil }

        do {
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
            let now = Date()
            var descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { workout in
                    workout.startDate >= weekStart && workout.startDate <= now
                },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            descriptor.fetchLimit = 12
            let weekWorkouts = try modelContainer.mainContext.fetch(descriptor)
            var recentDescriptor = FetchDescriptor<Workout>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            recentDescriptor.fetchLimit = 100
            let recentWorkouts = try modelContainer.mainContext.fetch(recentDescriptor)
            let categories = try modelContainer.mainContext.fetch(FetchDescriptor<WorkoutCategory>())

            let workoutPayloads = weekWorkouts.map { workout -> [String: Any] in
                [
                    "id": workout.id.uuidString,
                    "title": workout.primaryWorkoutDisplayName,
                    "startDate": workout.startDate.timeIntervalSince1970,
                    "duration": workout.duration,
                    "systemImage": workout.primaryWorkoutSystemImage,
                    "categories": categoryPayloads(for: workout),
                    "subcategories": subcategoryPayloads(for: workout),
                    "exercises": exercisePayloads(for: workout)
                ]
            }

            return [
                "event": "phoneWeekSnapshot",
                "sentAt": Date().timeIntervalSince1970,
                "workouts": Array(workoutPayloads),
                "quickLogExercises": quickLogExercisePayloads(from: recentWorkouts),
                "quickLogCategories": quickLogCategoryPayloads(from: categories)
            ]
        } catch {
            print("[WatchHealthKitSync] Week snapshot fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func categoryPayloads(for workout: Workout) -> [[String: Any]] {
        (workout.categories ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { category in
                [
                    "id": category.id.uuidString,
                    "name": category.name
                ]
            }
    }

    private func subcategoryPayloads(for workout: Workout) -> [[String: Any]] {
        (workout.subcategories ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { subcategory in
                var payload: [String: Any] = [
                    "id": subcategory.id.uuidString,
                    "name": subcategory.name
                ]
                if let category = subcategory.category {
                    payload["categoryName"] = category.name
                }
                return payload
            }
    }

    private func exercisePayloads(for workout: Workout) -> [[String: Any]] {
        (workout.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { exercise in
                var payload: [String: Any] = [
                    "id": exercise.id.uuidString,
                    "name": exercise.name,
                    "orderIndex": exercise.orderIndex
                ]
                if let sets = exercise.sets { payload["sets"] = sets }
                if let reps = exercise.reps { payload["reps"] = reps }
                if let weight = exercise.weight { payload["weight"] = weight }
                if let effortScore = exercise.effortScore { payload["effortScore"] = effortScore }
                if let notes = exercise.notes, !notes.isEmpty { payload["notes"] = notes }
                if let subcategory = exercise.subcategory {
                    payload["subcategoryName"] = subcategory.name
                    payload["subcategoryID"] = subcategory.id.uuidString
                }
                return payload
            }
    }

    private func quickLogExercisePayloads(from workouts: [Workout]) -> [[String: Any]] {
        var seenNames = Set<String>()
        var payloads: [[String: Any]] = []

        let sortedExercises = workouts
            .flatMap { $0.exercises ?? [] }
            .sorted {
                ($0.workout?.startDate ?? .distantPast) > ($1.workout?.startDate ?? .distantPast)
            }

        for exercise in sortedExercises {
            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }

            let key = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !seenNames.contains(key) else { continue }
            seenNames.insert(key)

            var payload: [String: Any] = [
                "name": trimmedName
            ]
            if let subcategory = exercise.subcategory {
                payload["subcategoryID"] = subcategory.id.uuidString
                payload["subcategoryName"] = subcategory.name
            }
            payloads.append(payload)

            if payloads.count >= 12 {
                break
            }
        }

        return payloads
    }

    private func quickLogCategoryPayloads(from categories: [WorkoutCategory]) -> [[String: Any]] {
        categories
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { category in
                [
                    "id": category.id.uuidString,
                    "name": category.name,
                    "workoutName": category.activityDisplayName,
                    "subcategories": quickLogSubcategoryPayloads(from: category.subcategories ?? [])
                ]
            }
    }

    private func quickLogSubcategoryPayloads(from subcategories: [WorkoutSubcategory]) -> [[String: Any]] {
        subcategories
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { subcategory in
                [
                    "id": subcategory.id.uuidString,
                    "name": subcategory.name,
                    "categoryName": subcategory.category?.name ?? "",
                    "exercises": quickLogTemplatePayloads(from: subcategory.exerciseTemplates ?? [])
                ]
            }
    }

    private func quickLogTemplatePayloads(from templates: [SubcategoryExercise]) -> [[String: Any]] {
        templates
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { template in
                [
                    "id": template.id.uuidString,
                    "name": template.name
                ]
            }
    }

    private func handleWatchQuickExerciseLogPayload(_ payload: [String: Any]) {
        guard let log = pendingQuickExerciseLog(from: payload) else { return }

        QuickExerciseLogStore.appendPendingLog(log)
        attachPendingQuickExerciseLogsIfPossible()
        updateWeekSnapshotContext()
    }

    private func pendingQuickExerciseLog(from payload: [String: Any]) -> PendingQuickExerciseLog? {
        guard let rawName = payload["exerciseName"] as? String else { return nil }

        let exerciseName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !exerciseName.isEmpty else { return nil }

        let id = (payload["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let loggedAt = doubleValue(payload["loggedAt"]).map(Date.init(timeIntervalSince1970:)) ?? Date()

        return PendingQuickExerciseLog(
            id: id,
            exerciseName: exerciseName,
            loggedAt: loggedAt,
            sets: intValue(payload["sets"]),
            reps: intValue(payload["reps"]),
            weight: doubleValue(payload["weight"]),
            effortScore: intValue(payload["effortScore"]),
            subcategoryID: (payload["subcategoryID"] as? String).flatMap(UUID.init(uuidString:)),
            source: payload["source"] as? String
        )
    }

    private func attachPendingQuickExerciseLogsIfPossible() {
        guard let modelContainer else { return }

        do {
            let context = modelContainer.mainContext
            let dayStart = Calendar.current.startOfDay(for: Date())
            let workouts = try context.fetch(FetchDescriptor<Workout>(
                predicate: #Predicate { workout in
                    workout.startDate >= dayStart
                },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ))
            let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
            QuickExerciseLogStore.attachPendingLogs(
                to: workouts,
                availableSubcategories: subcategories,
                in: context
            )
        } catch {
            print("[WatchHealthKitSync] Quick log attach failed: \(error.localizedDescription)")
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        return (value as? NSNumber)?.intValue
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        return (value as? NSNumber)?.doubleValue
    }
}

extension WatchHealthKitSyncBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchHealthKitSync] Activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            switch message["event"] as? String {
            case "healthKitWorkoutsChanged":
                WatchHealthKitSyncBridge.shared.scheduleImport(reason: "watch message")
            case "watchQuickExerciseLog":
                WatchHealthKitSyncBridge.shared.handleWatchQuickExerciseLogPayload(message)
            default:
                break
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            switch message["event"] as? String {
            case "requestPhoneWeekSnapshot":
                replyHandler(WatchHealthKitSyncBridge.shared.makeWeekSnapshotPayload() ?? [
                    "event": "phoneWeekSnapshot",
                    "workouts": []
                ])
            case "healthKitWorkoutsChanged":
                WatchHealthKitSyncBridge.shared.scheduleImport(reason: "watch message")
                replyHandler(["event": "healthKitWorkoutsChangedAck"])
            case "watchQuickExerciseLog":
                WatchHealthKitSyncBridge.shared.handleWatchQuickExerciseLogPayload(message)
                replyHandler(["event": "watchQuickExerciseLogAck"])
            default:
                replyHandler(["event": "unknown"])
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            switch applicationContext["event"] as? String {
            case "healthKitWorkoutsChanged":
                WatchHealthKitSyncBridge.shared.scheduleImport(reason: "watch context")
            case "watchQuickExerciseLog":
                WatchHealthKitSyncBridge.shared.handleWatchQuickExerciseLogPayload(applicationContext)
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            switch userInfo["event"] as? String {
            case "healthKitWorkoutsChanged":
                WatchHealthKitSyncBridge.shared.scheduleImport(reason: "watch transfer")
            case "watchQuickExerciseLog":
                WatchHealthKitSyncBridge.shared.handleWatchQuickExerciseLogPayload(userInfo)
            default:
                break
            }
        }
    }
}
