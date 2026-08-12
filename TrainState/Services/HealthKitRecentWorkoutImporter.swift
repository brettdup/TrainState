import Foundation
import HealthKit
import SwiftData
import CoreLocation

struct HealthKitRecentWorkoutMenuItem: Identifiable, Hashable, Codable {
    let hkUUID: String
    let startDate: Date
    let duration: TimeInterval
    let activityTypeRaw: Int
    let locationTypeRaw: Int?
    let sourceName: String
    let distanceKilometers: Double?
    let calories: Double?
    let workoutRating: Double?

    var id: String { hkUUID }

    var activityType: HKWorkoutActivityType {
        HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .other
    }

    var notificationDetail: HealthKitWorkoutImportNotificationDetail {
        HealthKitWorkoutImportNotificationDetail(
            workoutName: activityType.displayName(locationType: locationType),
            startDate: startDate,
            duration: duration,
            distanceKilometers: distanceKilometers,
            calories: calories,
            systemImageName: activityType.systemImage
        )
    }

    var locationType: HKWorkoutSessionLocationType? {
        guard let locationTypeRaw else { return nil }
        return HKWorkoutSessionLocationType(rawValue: locationTypeRaw)
    }

    init(workout: HKWorkout, workoutRating: Double?) {
        self.hkUUID = workout.uuid.uuidString
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.activityTypeRaw = Int(workout.workoutActivityType.rawValue)
        self.locationTypeRaw = Self.locationTypeRawValue(for: workout)
        self.sourceName = workout.sourceRevision.source.name
        self.distanceKilometers = workout.totalDistance?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
        self.calories = Self.activeEnergyKilocalories(for: workout)
        self.workoutRating = workoutRating
    }

    init(
        hkUUID: String,
        startDate: Date,
        duration: TimeInterval,
        activityTypeRaw: Int,
        locationTypeRaw: Int?,
        sourceName: String,
        distanceKilometers: Double?,
        calories: Double?,
        workoutRating: Double?
    ) {
        self.hkUUID = hkUUID
        self.startDate = startDate
        self.duration = duration
        self.activityTypeRaw = activityTypeRaw
        self.locationTypeRaw = locationTypeRaw
        self.sourceName = sourceName
        self.distanceKilometers = distanceKilometers
        self.calories = calories
        self.workoutRating = workoutRating
    }

    private static func locationTypeRawValue(for workout: HKWorkout) -> Int? {
        guard let indoorValue = workout.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber else {
            return nil
        }
        return indoorValue.boolValue
            ? HKWorkoutSessionLocationType.indoor.rawValue
            : HKWorkoutSessionLocationType.outdoor.rawValue
    }

    private static func activeEnergyKilocalories(for workout: HKWorkout) -> Double? {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }
        return workout.statistics(for: activeEnergyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
    }
}

enum HealthKitImportError: LocalizedError {
    case unavailable
    case authorizationDenied
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data is unavailable on this device."
        case .authorizationDenied:
            return "HealthKit access is denied. Enable workout read access in Health settings."
        case .unexpectedData:
            return "Unable to read workouts from HealthKit."
        }
    }
}

@MainActor
private final class HealthKitWorkoutImportGate {
    static let shared = HealthKitWorkoutImportGate()

    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    func run<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire() async {
        guard isRunning else {
            isRunning = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isRunning = false
            return
        }

        waiters.removeFirst().resume()
    }
}

@MainActor
final class HealthKitRecentWorkoutImporter {
    private static let anchoredWorkoutSyncAnchorKey = "healthKitWorkoutAutoImportAnchor"
    private static let hasCompletedFullHistoryImportKey = "healthKitHasCompletedFullHistoryImport"

    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let workoutRouteType = HKSeriesType.workoutRoute()
    private var sourceWorkoutsByUUID: [String: HKWorkout] = [:]

    func fetchRecentWorkouts(limit: Int = 30) async throws -> [HealthKitRecentWorkoutMenuItem] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitImportError.unavailable
        }

        try await requestReadAuthorization()

        return try await queryRecentWorkouts(limit: limit)
    }

    func importWorkout(_ item: HealthKitRecentWorkoutMenuItem, into context: ModelContext) async throws {
        try await HealthKitWorkoutImportGate.shared.run {
            try await self.importWorkoutLocked(item, into: context)
        }
    }

    private func importWorkoutLocked(_ item: HealthKitRecentWorkoutMenuItem, into context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Workout>()
        let existingWorkouts = try context.fetch(descriptor)

        let cleanupResult = consolidateDuplicateImportedWorkouts(
            existingWorkouts,
            in: context
        )
        let consolidatedWorkouts = cleanupResult.workouts

        if let importedWorkout = preferredImportedWorkout(for: item, in: consolidatedWorkouts) {
            let didReconcileReplacement = importedWorkout.hkUUID != item.hkUUID
            if didReconcileReplacement {
                try await reconcileReplacementWorkout(importedWorkout, using: item, in: context)
            }
            if let manualWorkout = matchingManualWorkout(for: item, in: consolidatedWorkouts) {
                try await mergeImportedWorkout(importedWorkout, into: manualWorkout, using: item, in: context)
            } else if cleanupResult.didChange || didReconcileReplacement {
                try context.save()
            }
            return
        }

        if let manualWorkout = matchingManualWorkout(for: item, in: consolidatedWorkouts) {
            try await attachWorkoutLocked(item, to: manualWorkout, in: context)
            return
        }

        _ = try await createImportedWorkout(from: item, in: context)
        try context.save()
    }

    func importWorkoutsBatch(_ items: [HealthKitRecentWorkoutMenuItem], into context: ModelContext) async throws {
        try await HealthKitWorkoutImportGate.shared.run {
            _ = try await self.importUniqueWorkoutItems(self.uniqueWorkoutItems(items), into: context)
        }
    }

    @discardableResult
    private func createImportedWorkout(
        from item: HealthKitRecentWorkoutMenuItem,
        in context: ModelContext
    ) async throws -> Workout {
        let workout = Workout(
            startDate: item.startDate,
            duration: item.duration,
            calories: item.calories,
            distance: item.distanceKilometers,
            rating: item.workoutRating,
            notes: "Imported from HealthKit",
            categories: nil,
            subcategories: nil,
            exercises: nil,
            hkActivityTypeRaw: item.activityTypeRaw,
            hkLocationTypeRaw: item.locationTypeRaw
        )
        workout.hkUUID = item.hkUUID
        context.insert(workout)

        if shouldFetchRoute(for: item),
           let sourceWorkout = try await findWorkout(uuidString: item.hkUUID),
           let importedRoute = try await fetchRouteLocations(for: sourceWorkout),
           !importedRoute.isEmpty {
            let route = WorkoutRoute()
            route.decodedRoute = downsampleLocations(importedRoute, maxPoints: 2000)
            route.workout = workout
            workout.route = route
            context.insert(route)
        }

        return workout
    }

    func importNewRecentWorkouts(into context: ModelContext, limit: Int = 10) async throws -> Int {
        try await HealthKitWorkoutImportGate.shared.run {
            let recentWorkouts = self.uniqueWorkoutItems(try await self.fetchRecentWorkouts(limit: limit))
            return try await self.importUniqueWorkoutItems(recentWorkouts, into: context)
        }
    }

    func importFullHistoryOnce(
        into context: ModelContext,
        progress: @escaping (_ completed: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws -> Int {
        try await HealthKitWorkoutImportGate.shared.run {
            guard !UserDefaults.standard.bool(forKey: Self.hasCompletedFullHistoryImportKey) else {
                return 0
            }

            guard HKHealthStore.isHealthDataAvailable() else {
                throw HealthKitImportError.unavailable
            }

            try await self.requestReadAuthorization()

            let workouts = self.uniqueWorkoutItems(try await self.queryAllWorkouts(includeRatings: false))
            progress(0, workouts.count)
            defer { self.sourceWorkoutsByUUID.removeAll(keepingCapacity: false) }
            let importedCount = try await self.importUniqueWorkoutItems(
                workouts,
                into: context,
                progress: progress
            )
            UserDefaults.standard.set(true, forKey: Self.hasCompletedFullHistoryImportKey)
            return importedCount
        }
    }

    func importNewAnchoredWorkouts(into context: ModelContext, initialLookbackDays: Int = 14) async throws -> Int {
        try await HealthKitWorkoutImportGate.shared.run {
            guard HKHealthStore.isHealthDataAvailable() else {
                throw HealthKitImportError.unavailable
            }

            try await self.requestReadAuthorization()

            let result = try await self.queryAnchoredWorkouts(initialLookbackDays: initialLookbackDays)
            let workoutItems = self.uniqueWorkoutItems(result.items)
            let importedCount = try await self.importUniqueWorkoutItems(
                workoutItems,
                deletedUUIDs: result.deletedUUIDs,
                into: context
            )
            self.saveWorkoutAnchor(result.anchor)
            return importedCount
        }
    }

    private func importUniqueWorkoutItems(
        _ items: [HealthKitRecentWorkoutMenuItem],
        deletedUUIDs: Set<String> = [],
        into context: ModelContext,
        progress: ((_ completed: Int, _ total: Int) -> Void)? = nil
    ) async throws -> Int {
        let descriptor = FetchDescriptor<Workout>()
        let existingWorkouts = try context.fetch(descriptor)
        let cleanupResult = consolidateDuplicateImportedWorkouts(
            existingWorkouts,
            deletedUUIDs: deletedUUIDs,
            in: context
        )
        let consolidatedWorkouts = cleanupResult.workouts
        var importedWorkoutsByUUID = consolidatedWorkouts.reduce(into: [String: Workout]()) { result, workout in
            guard let hkUUID = workout.hkUUID, !hkUUID.isEmpty else { return }
            result[hkUUID] = workout
        }
        var manualWorkouts = consolidatedWorkouts.filter { ($0.hkUUID ?? "").isEmpty }
        var mergedCount = 0
        var importedCount = 0
        var notificationDetails: [HealthKitWorkoutImportNotificationDetail] = []
        var completedCount = 0
        var pendingInsertCount = 0
        var didUpdateExistingWorkout = false

        if items.isEmpty {
            if cleanupResult.didChange {
                try context.save()
            }
            return 0
        }

        for item in items {
            defer {
                completedCount += 1
                progress?(completedCount, items.count)
            }

            let importedWorkout = importedWorkoutsByUUID[item.hkUUID] ?? preferredImportedWorkout(
                for: item,
                in: Array(importedWorkoutsByUUID.values),
                deletedUUIDs: deletedUUIDs
            )

            if let importedWorkout {
                let previousUUID = importedWorkout.hkUUID
                if previousUUID != item.hkUUID {
                    try await reconcileReplacementWorkout(importedWorkout, using: item, in: context)
                    didUpdateExistingWorkout = true
                    if let previousUUID {
                        importedWorkoutsByUUID.removeValue(forKey: previousUUID)
                    }
                    importedWorkoutsByUUID[item.hkUUID] = importedWorkout
                }

                guard let manualWorkout = matchingManualWorkout(for: item, in: manualWorkouts) else {
                    try await restoreMissingRouteIfNeeded(
                        for: importedWorkout,
                        using: item,
                        in: context
                    )
                    continue
                }
                try await mergeImportedWorkout(importedWorkout, into: manualWorkout, using: item, in: context)
                mergedCount += 1
                notificationDetails.append(item.notificationDetail)
                manualWorkouts.removeAll { $0.id == manualWorkout.id }
                importedWorkoutsByUUID[item.hkUUID] = manualWorkout
            } else if let manualWorkout = matchingManualWorkout(for: item, in: manualWorkouts) {
                try await attachWorkoutLocked(item, to: manualWorkout, in: context)
                mergedCount += 1
                notificationDetails.append(item.notificationDetail)
                manualWorkouts.removeAll { $0.id == manualWorkout.id }
                importedWorkoutsByUUID[item.hkUUID] = manualWorkout
            } else {
                let workout = try await createImportedWorkout(from: item, in: context)
                importedWorkoutsByUUID[item.hkUUID] = workout
                importedCount += 1
                pendingInsertCount += 1
                notificationDetails.append(item.notificationDetail)

                if pendingInsertCount >= 25 {
                    try context.save()
                    pendingInsertCount = 0
                }
            }
        }

        if pendingInsertCount > 0 || cleanupResult.didChange || didUpdateExistingWorkout {
            try context.save()
        }

        NotificationManager.shared.sendHealthKitWorkoutImportNotification(
            mergedCount: mergedCount,
            importedCount: importedCount,
            workoutDetails: notificationDetails
        )

        return mergedCount + importedCount
    }

    private func uniqueWorkoutItems(_ items: [HealthKitRecentWorkoutMenuItem]) -> [HealthKitRecentWorkoutMenuItem] {
        var seenUUIDs = Set<String>()
        return items.filter { item in
            seenUUIDs.insert(item.hkUUID).inserted
        }
    }

    private func requestReadAuthorization() async throws {
        var readTypes: Set<HKObjectType> = [workoutType]
        readTypes.insert(workoutRouteType)
        if let effortScoreType = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) {
            readTypes.insert(effortScoreType)
        }
        if let estimatedEffortType = HKObjectType.quantityType(forIdentifier: .estimatedWorkoutEffortScore) {
            readTypes.insert(estimatedEffortType)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            if isAuthorizationDenied(error) {
                throw HealthKitImportError.authorizationDenied
            }
            throw error
        }
    }

    private struct AnchoredWorkoutQueryResult {
        let items: [HealthKitRecentWorkoutMenuItem]
        let deletedUUIDs: Set<String>
        let anchor: HKQueryAnchor
    }

    private func queryAnchoredWorkouts(initialLookbackDays: Int) async throws -> AnchoredWorkoutQueryResult {
        let savedAnchor = loadWorkoutAnchor()
        let initialCutoff = Calendar.current.date(byAdding: .day, value: -initialLookbackDays, to: Date()) ?? .distantPast

        let result: ([HKWorkout], Set<String>, HKQueryAnchor) = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: workoutType,
                predicate: nil,
                anchor: savedAnchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let newAnchor else {
                    continuation.resume(throwing: HealthKitImportError.unexpectedData)
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                let deletedUUIDs = Set((deletedObjects ?? []).map { $0.uuid.uuidString })
                continuation.resume(returning: (workouts, deletedUUIDs, newAnchor))
            }
            healthStore.execute(query)
        }

        let workouts = savedAnchor == nil
            ? result.0.filter { $0.startDate >= initialCutoff }
            : result.0

        var items: [HealthKitRecentWorkoutMenuItem] = []
        items.reserveCapacity(workouts.count)
        for workout in workouts.sorted(by: { $0.startDate > $1.startDate }) {
            let rating = await fetchWorkoutRating(for: workout)
            items.append(HealthKitRecentWorkoutMenuItem(workout: workout, workoutRating: rating))
        }

        return AnchoredWorkoutQueryResult(items: items, deletedUUIDs: result.1, anchor: result.2)
    }

    private func loadWorkoutAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: Self.anchoredWorkoutSyncAnchorKey) else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveWorkoutAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.anchoredWorkoutSyncAnchorKey)
    }

    private func mergeImportedWorkout(
        _ importedWorkout: Workout,
        into manualWorkout: Workout,
        using item: HealthKitRecentWorkoutMenuItem,
        in context: ModelContext
    ) async throws {
        if manualWorkout.route == nil, let importedRoute = importedWorkout.route {
            importedRoute.workout = manualWorkout
            manualWorkout.route = importedRoute
            importedWorkout.route = nil
        }

        try await attachWorkoutLocked(item, to: manualWorkout, in: context)
        context.delete(importedWorkout)
        try context.save()
    }

    /// Attach HealthKit data to an already logged workout instead of creating a new one.
    /// This keeps manually-entered categories, subcategories, and exercises, while
    /// syncing timing from HealthKit and filling additional metrics.
    func attachWorkout(_ item: HealthKitRecentWorkoutMenuItem, to workout: Workout, in context: ModelContext) async throws {
        try await HealthKitWorkoutImportGate.shared.run {
            let linkedWorkouts = try context.fetch(FetchDescriptor<Workout>())
                .filter { $0.id != workout.id && $0.hkUUID == item.hkUUID }
            for linkedWorkout in linkedWorkouts {
                self.mergeDuplicateWorkout(linkedWorkout, into: workout, in: context)
                context.delete(linkedWorkout)
            }
            try await self.attachWorkoutLocked(item, to: workout, in: context)
        }
    }

    private func attachWorkoutLocked(
        _ item: HealthKitRecentWorkoutMenuItem,
        to workout: Workout,
        in context: ModelContext
    ) async throws {
        // Link identity back to HealthKit so this workout won't be imported twice.
        workout.hkUUID = item.hkUUID
        workout.hkActivityTypeRaw = item.activityTypeRaw
        workout.hkLocationTypeRaw = item.locationTypeRaw

        // Keep attached workout timing aligned to the HealthKit source.
        workout.startDate = item.startDate
        workout.duration = item.duration

        // Fill remaining metrics without overriding explicit manual values.
        if (workout.distance ?? 0) <= 0, let distance = item.distanceKilometers, distance > 0 {
            workout.distance = distance
        }
        if workout.calories == nil, let calories = item.calories {
            workout.calories = calories
        }
        if workout.rating == nil, let rating = item.workoutRating {
            workout.rating = rating
        }

        // Attach route if one doesn't already exist.
        if workout.route == nil,
           let sourceWorkout = try await findWorkout(uuidString: item.hkUUID),
           let importedRoute = try await fetchRouteLocations(for: sourceWorkout),
           !importedRoute.isEmpty {
            let route = WorkoutRoute()
            route.decodedRoute = downsampleLocations(importedRoute, maxPoints: 2000)
            route.workout = workout
            workout.route = route
            context.insert(route)
        }

        try context.save()
    }

    private func reconcileReplacementWorkout(
        _ workout: Workout,
        using item: HealthKitRecentWorkoutMenuItem,
        in context: ModelContext
    ) async throws {
        let isUnmodifiedImport = workout.notes == "Imported from HealthKit" &&
            (workout.categories?.isEmpty ?? true) &&
            (workout.subcategories?.isEmpty ?? true) &&
            (workout.exercises?.isEmpty ?? true)

        workout.hkUUID = item.hkUUID
        workout.hkActivityTypeRaw = item.activityTypeRaw
        workout.hkLocationTypeRaw = item.locationTypeRaw
        workout.startDate = item.startDate
        workout.duration = item.duration

        if isUnmodifiedImport {
            workout.distance = item.distanceKilometers
            workout.calories = item.calories
            workout.rating = item.workoutRating ?? workout.rating
        } else {
            if (workout.distance ?? 0) <= 0, let distance = item.distanceKilometers, distance > 0 {
                workout.distance = distance
            }
            if workout.calories == nil {
                workout.calories = item.calories
            }
            if workout.rating == nil {
                workout.rating = item.workoutRating
            }
        }

        try await restoreMissingRouteIfNeeded(for: workout, using: item, in: context)
    }

    private func queryRecentWorkouts(limit: Int) async throws -> [HealthKitRecentWorkoutMenuItem] {
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let startDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: [])
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(throwing: HealthKitImportError.unexpectedData)
                    return
                }

                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }

        var menuItems: [HealthKitRecentWorkoutMenuItem] = []
        menuItems.reserveCapacity(workouts.count)
        for workout in workouts {
            sourceWorkoutsByUUID[workout.uuid.uuidString] = workout
            let rating = await fetchWorkoutRating(for: workout)
            menuItems.append(HealthKitRecentWorkoutMenuItem(workout: workout, workoutRating: rating))
        }
        return menuItems
    }

    private func queryAllWorkouts(includeRatings: Bool) async throws -> [HealthKitRecentWorkoutMenuItem] {
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(throwing: HealthKitImportError.unexpectedData)
                    return
                }

                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }

        var menuItems: [HealthKitRecentWorkoutMenuItem] = []
        menuItems.reserveCapacity(workouts.count)
        for workout in workouts {
            sourceWorkoutsByUUID[workout.uuid.uuidString] = workout
            let rating = includeRatings ? await fetchWorkoutRating(for: workout) : nil
            menuItems.append(HealthKitRecentWorkoutMenuItem(workout: workout, workoutRating: rating))
        }
        return menuItems
    }

    private struct DuplicateCleanupResult {
        let workouts: [Workout]
        let didChange: Bool
    }

    private func preferredImportedWorkout(
        for item: HealthKitRecentWorkoutMenuItem,
        in workouts: [Workout],
        deletedUUIDs: Set<String> = []
    ) -> Workout? {
        workouts
            .filter { workout in
                guard let hkUUID = workout.hkUUID, !hkUUID.isEmpty else { return false }
                return hkUUID == item.hkUUID ||
                    isLikelySameHealthKitWorkout(workout, as: item) ||
                    (deletedUUIDs.contains(hkUUID) && hasMatchingWorkoutTiming(workout, item))
            }
            .sorted { lhs, rhs in
                let lhsIsExact = lhs.hkUUID == item.hkUUID
                let rhsIsExact = rhs.hkUUID == item.hkUUID
                if lhsIsExact != rhsIsExact {
                    return lhsIsExact
                }

                let lhsWasDeleted = lhs.hkUUID.map(deletedUUIDs.contains) ?? false
                let rhsWasDeleted = rhs.hkUUID.map(deletedUUIDs.contains) ?? false
                if lhsWasDeleted != rhsWasDeleted {
                    return lhsWasDeleted
                }

                return workoutPreservationScore(lhs) > workoutPreservationScore(rhs)
            }
            .first
    }

    private func isLikelySameHealthKitWorkout(
        _ workout: Workout,
        as item: HealthKitRecentWorkoutMenuItem
    ) -> Bool {
        let activityMatches: Bool
        if let activityTypeRaw = workout.hkActivityTypeRaw {
            activityMatches = activityTypeRaw == item.activityTypeRaw
        } else {
            activityMatches = workout.type == item.activityType.mappedWorkoutType
        }

        guard activityMatches else { return false }
        return hasMatchingWorkoutTiming(workout, item)
    }

    private func isLikelySameHealthKitWorkout(_ lhs: Workout, _ rhs: Workout) -> Bool {
        let activityMatches: Bool
        if let lhsRaw = lhs.hkActivityTypeRaw, let rhsRaw = rhs.hkActivityTypeRaw {
            activityMatches = lhsRaw == rhsRaw
        } else {
            activityMatches = lhs.type == rhs.type
        }

        guard activityMatches else { return false }
        guard abs(lhs.startDate.timeIntervalSince(rhs.startDate)) <= 90 else { return false }
        return durationsLikelyMatch(lhs.duration, rhs.duration)
    }

    private func hasMatchingWorkoutTiming(_ workout: Workout, _ item: HealthKitRecentWorkoutMenuItem) -> Bool {
        guard abs(workout.startDate.timeIntervalSince(item.startDate)) <= 90 else { return false }
        return durationsLikelyMatch(workout.duration, item.duration)
    }

    private func durationsLikelyMatch(_ lhs: TimeInterval, _ rhs: TimeInterval) -> Bool {
        let tolerance = max(120, max(lhs, rhs) * 0.1)
        return abs(lhs - rhs) <= tolerance
    }

    private func consolidateDuplicateImportedWorkouts(
        _ workouts: [Workout],
        deletedUUIDs: Set<String> = [],
        in context: ModelContext
    ) -> DuplicateCleanupResult {
        let importedWorkouts = workouts
            .filter { !($0.hkUUID ?? "").isEmpty }
            .sorted { $0.startDate < $1.startDate }

        var groups: [[Workout]] = []
        var groupIndexByUUID: [String: Int] = [:]
        for workout in importedWorkouts {
            let hkUUID = workout.hkUUID ?? ""
            var matchingGroupIndex = groupIndexByUUID[hkUUID]
            if matchingGroupIndex == nil {
                for index in groups.indices.reversed() {
                    guard let reference = groups[index].first else { continue }
                    if workout.startDate.timeIntervalSince(reference.startDate) > 90 {
                        break
                    }
                    if isLikelySameHealthKitWorkout(reference, workout) {
                        matchingGroupIndex = index
                        break
                    }
                }
            }

            if let matchingGroupIndex {
                groups[matchingGroupIndex].append(workout)
                groupIndexByUUID[hkUUID] = matchingGroupIndex
            } else {
                groups.append([workout])
                groupIndexByUUID[hkUUID] = groups.index(before: groups.endIndex)
            }
        }

        var deletedWorkoutIDs = Set<UUID>()
        for group in groups where group.count > 1 {
            // If two copies were both independently edited, keep both rather than
            // guessing which user-authored relationships should be discarded.
            guard group.filter(hasUserAuthoredContent).count <= 1 else { continue }

            let survivor = group.sorted { lhs, rhs in
                let lhsScore = workoutPreservationScore(lhs)
                let rhsScore = workoutPreservationScore(rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }

                let lhsIsCurrent = lhs.hkUUID.map { !deletedUUIDs.contains($0) } ?? false
                let rhsIsCurrent = rhs.hkUUID.map { !deletedUUIDs.contains($0) } ?? false
                if lhsIsCurrent != rhsIsCurrent {
                    return lhsIsCurrent
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }.first!

            for duplicate in group where duplicate.id != survivor.id {
                mergeDuplicateWorkout(duplicate, into: survivor, in: context)
                deletedWorkoutIDs.insert(duplicate.id)
                context.delete(duplicate)
            }
        }

        return DuplicateCleanupResult(
            workouts: workouts.filter { !deletedWorkoutIDs.contains($0.id) },
            didChange: !deletedWorkoutIDs.isEmpty
        )
    }

    private func workoutPreservationScore(_ workout: Workout) -> Int {
        var score = 0
        score += (workout.exercises?.count ?? 0) * 20
        score += (workout.subcategoryRatings?.count ?? 0) * 10
        score += (workout.categories?.count ?? 0) * 5
        score += (workout.subcategories?.count ?? 0) * 5
        if workout.route != nil { score += 4 }
        if let notes = workout.notes,
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           notes != "Imported from HealthKit" {
            score += 8
        }
        if workout.rating != nil { score += 2 }
        if workout.distance != nil { score += 1 }
        if workout.calories != nil { score += 1 }
        return score
    }

    private func hasUserAuthoredContent(_ workout: Workout) -> Bool {
        if !(workout.exercises?.isEmpty ?? true) { return true }
        if !(workout.subcategoryRatings?.isEmpty ?? true) { return true }
        if !(workout.categories?.isEmpty ?? true) { return true }
        if !(workout.subcategories?.isEmpty ?? true) { return true }
        if let notes = workout.notes,
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           notes != "Imported from HealthKit" {
            return true
        }
        return false
    }

    private func mergeDuplicateWorkout(_ duplicate: Workout, into survivor: Workout, in context: ModelContext) {
        for category in duplicate.categories ?? [] {
            survivor.addCategory(category)
        }
        for subcategory in duplicate.subcategories ?? [] {
            survivor.addSubcategory(subcategory)
        }

        if (survivor.exercises?.isEmpty ?? true), let exercises = duplicate.exercises, !exercises.isEmpty {
            duplicate.exercises = []
            survivor.exercises = exercises
            for exercise in exercises {
                exercise.workout = survivor
            }
        }

        if (survivor.subcategoryRatings?.isEmpty ?? true),
           let ratings = duplicate.subcategoryRatings,
           !ratings.isEmpty {
            duplicate.subcategoryRatings = []
            survivor.subcategoryRatings = ratings
            for rating in ratings {
                rating.workout = survivor
            }
        }

        if survivor.route == nil, let route = duplicate.route {
            duplicate.route = nil
            survivor.route = route
            route.workout = survivor
        } else if let duplicateRoute = duplicate.route {
            duplicate.route = nil
            context.delete(duplicateRoute)
        }

        if survivor.distance == nil { survivor.distance = duplicate.distance }
        if survivor.calories == nil { survivor.calories = duplicate.calories }
        if survivor.rating == nil { survivor.rating = duplicate.rating }
        if survivor.notes == nil || survivor.notes == "Imported from HealthKit" {
            if let duplicateNotes = duplicate.notes,
               !duplicateNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                survivor.notes = duplicateNotes
            }
        }
        if survivor.hkActivityTypeRaw == nil { survivor.hkActivityTypeRaw = duplicate.hkActivityTypeRaw }
        if survivor.hkLocationTypeRaw == nil { survivor.hkLocationTypeRaw = duplicate.hkLocationTypeRaw }
    }

    private func matchingManualWorkout(
        for item: HealthKitRecentWorkoutMenuItem,
        in workouts: [Workout],
        calendar: Calendar = .current
    ) -> Workout? {
        workouts
            .filter { workout in
                workout.hkUUID == nil &&
                calendar.isDate(workout.startDate, inSameDayAs: item.startDate) &&
                workout.type == item.activityType.mappedWorkoutType
            }
            .sorted { lhs, rhs in
                let lhsHasExercises = !(lhs.exercises?.isEmpty ?? true)
                let rhsHasExercises = !(rhs.exercises?.isEmpty ?? true)
                if lhsHasExercises != rhsHasExercises {
                    return lhsHasExercises
                }
                return abs(lhs.startDate.timeIntervalSince(item.startDate)) <
                    abs(rhs.startDate.timeIntervalSince(item.startDate))
            }
            .first
    }

    private func shouldFetchRoute(for item: HealthKitRecentWorkoutMenuItem) -> Bool {
        guard item.distanceKilometers != nil,
              item.locationType == .outdoor else {
            return false
        }

        switch item.activityType {
        case .walking,
             .running,
             .cycling,
             .hiking,
             .wheelchairWalkPace,
             .wheelchairRunPace,
             .crossCountrySkiing,
             .downhillSkiing,
             .snowboarding,
             .skatingSports,
             .paddleSports,
             .rowing,
             .sailing,
             .surfingSports,
             .swimming:
            return true
        default:
            return false
        }
    }

    private func restoreMissingRouteIfNeeded(
        for workout: Workout,
        using item: HealthKitRecentWorkoutMenuItem,
        in context: ModelContext
    ) async throws {
        guard workout.route == nil,
              shouldFetchRoute(for: item),
              let sourceWorkout = try await findWorkout(uuidString: item.hkUUID),
              let importedRoute = try await fetchRouteLocations(for: sourceWorkout),
              !importedRoute.isEmpty else {
            return
        }

        let route = WorkoutRoute()
        route.decodedRoute = downsampleLocations(importedRoute, maxPoints: 2000)
        route.workout = workout
        workout.route = route
        context.insert(route)
        try context.save()
    }

    private func isAuthorizationDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == HKErrorDomain && nsError.code == HKError.errorAuthorizationDenied.rawValue
    }

    private func findWorkout(uuidString: String) async throws -> HKWorkout? {
        if let sourceWorkout = sourceWorkoutsByUUID[uuidString] {
            return sourceWorkout
        }

        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObject(with: uuid)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples?.first as? HKWorkout))
            }
            healthStore.execute(query)
        }
    }

    private func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation]? {
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(
                sampleType: workoutRouteType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let routeSamples = (samples as? [HKWorkoutRoute]) ?? []
                continuation.resume(returning: routeSamples)
            }
            healthStore.execute(query)
        }

        guard !routes.isEmpty else { return nil }

        var allLocations: [CLLocation] = []
        for route in routes {
            let locations = try await fetchLocations(for: route)
            allLocations.append(contentsOf: locations)
        }
        return allLocations.isEmpty ? nil : allLocations.sorted { $0.timestamp < $1.timestamp }
    }

    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var collectedLocations: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let locations {
                    collectedLocations.append(contentsOf: locations)
                }
                if done {
                    continuation.resume(returning: collectedLocations)
                }
            }
            healthStore.execute(query)
        }
    }

    private func downsampleLocations(_ locations: [CLLocation], maxPoints: Int) -> [CLLocation] {
        guard locations.count > maxPoints, maxPoints > 1 else { return locations }
        let step = Double(locations.count - 1) / Double(maxPoints - 1)
        var sampled: [CLLocation] = []
        sampled.reserveCapacity(maxPoints)
        for i in 0..<maxPoints {
            let index = Int((Double(i) * step).rounded(.toNearestOrAwayFromZero))
            sampled.append(locations[min(index, locations.count - 1)])
        }
        return sampled
    }

    private func fetchWorkoutRating(for workout: HKWorkout) async -> Double? {
        guard #available(iOS 18.0, *) else { return nil }
        do {
            let predicate = HKQuery.predicateForObject(with: workout.uuid)
            let descriptor = HKWorkoutEffortRelationshipQueryDescriptor(
                predicate: predicate,
                anchor: nil,
                option: .mostRelevant
            )
            let result = try await descriptor.result(for: healthStore)
            for relationship in result.relationships {
                if let score = ratingFromSamples(relationship.samples) {
                    return score
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func ratingFromSamples(_ samples: [HKSample]?) -> Double? {
        guard let samples else { return nil }
        for sample in samples {
            guard let quantitySample = sample as? HKQuantitySample else { continue }
            let identifier = quantitySample.quantityType.identifier
            if identifier == HKQuantityTypeIdentifier.workoutEffortScore.rawValue ||
                identifier == HKQuantityTypeIdentifier.estimatedWorkoutEffortScore.rawValue {
                return quantitySample.quantity.doubleValue(for: HKUnit(from: "appleEffortScore"))
            }
        }
        return nil
    }
}

@MainActor
final class HealthKitWorkoutAutoImportService {
    static let shared = HealthKitWorkoutAutoImportService()

    private let healthStore = HKHealthStore()
    private let importer = HealthKitRecentWorkoutImporter()
    private var observerQuery: HKObserverQuery?
    private var importTask: Task<Void, Never>?
    private var hasStarted = false

    private init() {}

    func start(modelContainer: ModelContainer) async {
        guard !hasStarted else { return }

        guard HKHealthStore.isHealthDataAvailable() else { return }

        let workoutType = HKObjectType.workoutType()
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [workoutType])
            try await enableBackgroundDelivery(for: workoutType)
            observeWorkouts(modelContainer: modelContainer, workoutType: workoutType)
            hasStarted = true
            scheduleImport(modelContainer: modelContainer)
        } catch {
            print("[HealthKitAutoImport] Failed to start: \(error.localizedDescription)")
        }
    }

    private func observeWorkouts(modelContainer: ModelContainer, workoutType: HKSampleType) {
        if let observerQuery {
            healthStore.stop(observerQuery)
        }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                print("[HealthKitAutoImport] Observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            Task { @MainActor in
                self?.scheduleImport(modelContainer: modelContainer) {
                    completionHandler()
                }
            }
        }

        observerQuery = query
        healthStore.execute(query)
    }

    private func scheduleImport(modelContainer: ModelContainer, completion: (() -> Void)? = nil) {
        importTask = Task { @MainActor in
            defer { completion?() }

            do {
                let importedCount = try await importer.importNewAnchoredWorkouts(into: modelContainer.mainContext)
                if importedCount > 0 {
                    print("[HealthKitAutoImport] Imported \(importedCount) new workout(s).")
                }
            } catch {
                print("[HealthKitAutoImport] Import failed: \(error.localizedDescription)")
            }
        }
    }

    private func enableBackgroundDelivery(for workoutType: HKSampleType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(
                for: workoutType,
                frequency: .immediate
            ) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitImportError.authorizationDenied)
                }
            }
        }
    }
}
