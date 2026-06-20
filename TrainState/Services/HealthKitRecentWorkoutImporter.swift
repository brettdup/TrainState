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
            calories: calories
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
final class HealthKitRecentWorkoutImporter {
    private static var isImportingNewRecentWorkouts = false
    private static var isImportingAnchoredWorkouts = false
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
        let descriptor = FetchDescriptor<Workout>()
        let existingWorkouts = try context.fetch(descriptor)

        if let importedWorkout = existingWorkouts.first(where: { $0.hkUUID == item.hkUUID }) {
            if let manualWorkout = matchingManualWorkout(for: item, in: existingWorkouts) {
                try await mergeImportedWorkout(importedWorkout, into: manualWorkout, using: item, in: context)
            }
            return
        }

        if let manualWorkout = matchingManualWorkout(for: item, in: existingWorkouts) {
            try await attachWorkout(item, to: manualWorkout, in: context)
            return
        }

        _ = try await createImportedWorkout(from: item, in: context)
        try context.save()
    }

    func importWorkoutsBatch(_ items: [HealthKitRecentWorkoutMenuItem], into context: ModelContext) async throws {
        guard !items.isEmpty else { return }

        let descriptor = FetchDescriptor<Workout>()
        var existingWorkouts = try context.fetch(descriptor)

        for item in uniqueWorkoutItems(items) {
            if let importedWorkout = existingWorkouts.first(where: { $0.hkUUID == item.hkUUID }) {
                if let manualWorkout = matchingManualWorkout(for: item, in: existingWorkouts) {
                    try await mergeImportedWorkout(importedWorkout, into: manualWorkout, using: item, in: context)
                }
                existingWorkouts = try context.fetch(descriptor)
                continue
            }

            if let manualWorkout = matchingManualWorkout(for: item, in: existingWorkouts) {
                try await attachWorkout(item, to: manualWorkout, in: context)
                existingWorkouts = try context.fetch(descriptor)
                continue
            }

            _ = try await createImportedWorkout(from: item, in: context)
            existingWorkouts = try context.fetch(descriptor)
        }

        try context.save()
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
        guard !Self.isImportingNewRecentWorkouts else { return 0 }
        Self.isImportingNewRecentWorkouts = true
        defer { Self.isImportingNewRecentWorkouts = false }

        let recentWorkouts = uniqueWorkoutItems(try await fetchRecentWorkouts(limit: limit))
        return try await importUniqueWorkoutItems(recentWorkouts, into: context)
    }

    func importFullHistoryOnce(
        into context: ModelContext,
        progress: @escaping (_ completed: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws -> Int {
        guard !UserDefaults.standard.bool(forKey: Self.hasCompletedFullHistoryImportKey) else {
            return 0
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitImportError.unavailable
        }

        try await requestReadAuthorization()

        let workouts = uniqueWorkoutItems(try await queryAllWorkouts(includeRatings: false))
        progress(0, workouts.count)
        defer { sourceWorkoutsByUUID.removeAll(keepingCapacity: false) }
        let importedCount = try await importUniqueWorkoutItems(
            workouts,
            into: context,
            progress: progress
        )
        UserDefaults.standard.set(true, forKey: Self.hasCompletedFullHistoryImportKey)
        return importedCount
    }

    func importNewAnchoredWorkouts(into context: ModelContext, initialLookbackDays: Int = 14) async throws -> Int {
        guard !Self.isImportingAnchoredWorkouts else { return 0 }
        Self.isImportingAnchoredWorkouts = true
        defer { Self.isImportingAnchoredWorkouts = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitImportError.unavailable
        }

        try await requestReadAuthorization()

        let result = try await queryAnchoredWorkouts(initialLookbackDays: initialLookbackDays)
        let workoutItems = uniqueWorkoutItems(result.items)
        let importedCount = try await importUniqueWorkoutItems(workoutItems, into: context)
        saveWorkoutAnchor(result.anchor)
        return importedCount
    }

    private func importUniqueWorkoutItems(
        _ items: [HealthKitRecentWorkoutMenuItem],
        into context: ModelContext,
        progress: ((_ completed: Int, _ total: Int) -> Void)? = nil
    ) async throws -> Int {
        guard !items.isEmpty else { return 0 }

        let descriptor = FetchDescriptor<Workout>()
        var existingWorkouts = try context.fetch(descriptor)
        var mergedCount = 0
        var importedCount = 0
        var notificationDetails: [HealthKitWorkoutImportNotificationDetail] = []
        var completedCount = 0
        var pendingInsertCount = 0

        for item in items {
            defer {
                completedCount += 1
                progress?(completedCount, items.count)
            }

            if let importedWorkout = existingWorkouts.first(where: { $0.hkUUID == item.hkUUID }) {
                guard let manualWorkout = matchingManualWorkout(for: item, in: existingWorkouts) else {
                    continue
                }
                try await mergeImportedWorkout(importedWorkout, into: manualWorkout, using: item, in: context)
                mergedCount += 1
                notificationDetails.append(item.notificationDetail)
                existingWorkouts = try context.fetch(descriptor)
            } else if let manualWorkout = matchingManualWorkout(for: item, in: existingWorkouts) {
                try await attachWorkout(item, to: manualWorkout, in: context)
                mergedCount += 1
                notificationDetails.append(item.notificationDetail)
                existingWorkouts = try context.fetch(descriptor)
            } else {
                let workout = try await createImportedWorkout(from: item, in: context)
                existingWorkouts.append(workout)
                importedCount += 1
                pendingInsertCount += 1
                notificationDetails.append(item.notificationDetail)

                if pendingInsertCount >= 25 {
                    try context.save()
                    pendingInsertCount = 0
                }
            }
        }

        if pendingInsertCount > 0 {
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
        let anchor: HKQueryAnchor
    }

    private func queryAnchoredWorkouts(initialLookbackDays: Int) async throws -> AnchoredWorkoutQueryResult {
        let savedAnchor = loadWorkoutAnchor()
        let initialCutoff = Calendar.current.date(byAdding: .day, value: -initialLookbackDays, to: Date()) ?? .distantPast

        let result: ([HKWorkout], HKQueryAnchor) = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: workoutType,
                predicate: nil,
                anchor: savedAnchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let newAnchor else {
                    continuation.resume(throwing: HealthKitImportError.unexpectedData)
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: (workouts, newAnchor))
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

        return AnchoredWorkoutQueryResult(items: items, anchor: result.1)
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

        try await attachWorkout(item, to: manualWorkout, in: context)
        context.delete(importedWorkout)
        try context.save()
    }

    /// Attach HealthKit data to an already logged workout instead of creating a new one.
    /// This keeps manually-entered categories, subcategories, and exercises, while
    /// syncing timing from HealthKit and filling additional metrics.
    func attachWorkout(_ item: HealthKitRecentWorkoutMenuItem, to workout: Workout, in context: ModelContext) async throws {
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
