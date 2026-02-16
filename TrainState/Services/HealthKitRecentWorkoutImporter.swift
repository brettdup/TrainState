import Foundation
import HealthKit
import SwiftData
import CoreLocation

struct HealthKitRecentWorkoutMenuItem: Identifiable, Hashable, Codable {
    let hkUUID: String
    let startDate: Date
    let duration: TimeInterval
    let activityTypeRaw: Int
    let sourceName: String
    let distanceKilometers: Double?
    let calories: Double?
    let workoutRating: Double?

    var id: String { hkUUID }

    var activityType: HKWorkoutActivityType {
        HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .other
    }

    init(workout: HKWorkout, workoutRating: Double?) {
        self.hkUUID = workout.uuid.uuidString
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.activityTypeRaw = Int(workout.workoutActivityType.rawValue)
        self.sourceName = workout.sourceRevision.source.name
        self.distanceKilometers = workout.totalDistance?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
        self.calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.workoutRating = workoutRating
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
    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let workoutRouteType = HKSeriesType.workoutRoute()

    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HealthKitRecentWorkoutMenuItem] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitImportError.unavailable
        }

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

        return try await queryRecentWorkouts(limit: limit)
    }

    func importWorkout(_ item: HealthKitRecentWorkoutMenuItem, into context: ModelContext) async throws {
        let workout = Workout(
            type: mapWorkoutType(item.activityType),
            startDate: item.startDate,
            duration: item.duration,
            calories: item.calories,
            distance: item.distanceKilometers,
            rating: item.workoutRating,
            notes: "Imported from HealthKit",
            categories: nil,
            subcategories: nil,
            exercises: nil,
            hkActivityTypeRaw: item.activityTypeRaw
        )
        workout.hkUUID = item.hkUUID

        if let sourceWorkout = try await findWorkout(uuidString: item.hkUUID),
           let importedRoute = try await fetchRouteLocations(for: sourceWorkout),
           !importedRoute.isEmpty {
            let route = WorkoutRoute()
            route.decodedRoute = downsampleLocations(importedRoute, maxPoints: 2000)
            route.workout = workout
            workout.route = route
            context.insert(route)
        }

        context.insert(workout)
        try context.save()
    }

    /// Attach HealthKit data to an already logged workout instead of creating a new one.
    /// This keeps manually-entered categories, subcategories, and exercises, while
    /// syncing timing from HealthKit and filling additional metrics.
    func attachWorkout(_ item: HealthKitRecentWorkoutMenuItem, to workout: Workout, in context: ModelContext) async throws {
        // Link identity back to HealthKit so this workout won't be imported twice.
        workout.hkUUID = item.hkUUID
        workout.hkActivityTypeRaw = item.activityTypeRaw

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
            let rating = await fetchWorkoutRating(for: workout)
            menuItems.append(HealthKitRecentWorkoutMenuItem(workout: workout, workoutRating: rating))
        }
        return menuItems
    }

    private func mapWorkoutType(_ activity: HKWorkoutActivityType) -> WorkoutType {
        switch activity {
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .yoga:
            return .yoga
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .strength
        case .walking, .hiking, .elliptical, .rowing, .stairClimbing, .mixedCardio:
            return .cardio
        default:
            return .other
        }
    }

    private func isAuthorizationDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == HKErrorDomain && nsError.code == HKError.errorAuthorizationDenied.rawValue
    }

    private func findWorkout(uuidString: String) async throws -> HKWorkout? {
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
