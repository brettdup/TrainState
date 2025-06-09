import Foundation
import HealthKit
import Combine
import SwiftData
import CoreLocation

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    public init() {}
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Define the types we want to read from HealthKit
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKSeriesType.workoutRoute() as HKObjectType
        ]
        
        // Define the types we want to write to HealthKit
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKSeriesType.workoutRoute() as HKSampleType
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func requestAuthorizationAsync() async throws -> Bool {
        // Define the types we want to read from HealthKit
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKSeriesType.workoutRoute() as HKObjectType
        ]
        
        // Define the types we want to write to HealthKit
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKSeriesType.workoutRoute() as HKSampleType
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    func checkAuthorizationStatusAsync() async throws -> Bool {
        let workoutType = HKObjectType.workoutType()
        
        let status = healthStore.authorizationStatus(for: workoutType)
        
        return status == .sharingAuthorized
    }
    
    func saveWorkout(_ workout: Workout, completion: @escaping (Bool, Error?) -> Void) {
        // Convert our workout type to HKWorkoutActivityType
        let activityType = convertToHKWorkoutActivityType(workout.type)
        
        // Create the workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        
        // Create the workout
        let workout = HKWorkout(
            activityType: activityType,
            start: workout.startDate,
            end: workout.startDate.addingTimeInterval(workout.duration),
            duration: workout.duration,
            totalEnergyBurned: workout.calories.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) },
            totalDistance: workout.distance.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            metadata: nil
        )
        
        // Save the workout to HealthKit
        healthStore.save(workout) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func fetchWorkouts(completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        // Create a predicate that matches all workouts
        let workoutPredicate = HKQuery.predicateForWorkouts(with: .greaterThan, duration: 0)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: workoutPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let workouts = samples as? [HKWorkout]
                completion(workouts, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func importWorkoutsToCoreData(context: ModelContext) async throws {
        // Fetch workouts from HealthKit
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            fetchWorkouts { workouts, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workouts ?? [])
                }
            }
        }
        print("[HealthKit] Total workouts fetched: \(workouts.count)")

        // Only keep running workouts, sorted by startDate descending, and take the 10 most recent
        let runningWorkouts = workouts
            .filter { $0.workoutActivityType == .running }
            .sorted { $0.startDate > $1.startDate }
            .prefix(10)
        print("[HealthKit] Importing only \(runningWorkouts.count) most recent running workouts")

        let totalWorkouts = runningWorkouts.count
        var processedWorkouts = 0

        for hkWorkout in runningWorkouts {
            print("[HealthKit] Importing workout: \(hkWorkout.uuid) type: \(hkWorkout.workoutActivityType.rawValue) name: \(hkWorkout.workoutActivityType.name)")
            var distance: Double? = nil
            distance = hkWorkout.totalDistance?.doubleValue(for: .meter())

            let locations: [CLLocation]? = try await withCheckedContinuation { continuation in
                self.fetchRoute(for: hkWorkout) { locs in
                    if let locs = locs {
                        print("[HealthKit] Fetched route for workout \(hkWorkout.uuid): \(locs.count) points")
                    } else {
                        print("[HealthKit] No route found for workout \(hkWorkout.uuid)")
                    }
                    continuation.resume(returning: locs)
                }
            }
            print("[HealthKit] Locations right after fetch: \(locations?.count ?? -1)")
            let workoutType = convertFromHKWorkoutActivityType(hkWorkout.workoutActivityType)
            let workout = Workout(
                type: workoutType,
                startDate: hkWorkout.startDate,
                duration: hkWorkout.duration,
                calories: hkWorkout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
                distance: distance,
                notes: "Imported from Apple Health",
                healthKitUUID: hkWorkout.uuid
            )
            if let locs = locations, !locs.isEmpty {
                workout.route = locs
            }
            print("[HealthKit] Workout.route after set: \(workout.route?.count ?? -1)")
            // Deduplication: skip if already imported
            let healthKitUUID = hkWorkout.uuid
            let existing = try? context.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.healthKitUUID == healthKitUUID })
            )
            if existing?.isEmpty == false {
                print("[HealthKit] Skipping duplicate workout: \(hkWorkout.uuid)")
                continue
            }
            context.insert(workout)

            processedWorkouts += 1
            let progress = Double(processedWorkouts) / Double(totalWorkouts)
            NotificationCenter.default.post(
                name: NSNotification.Name("ImportProgressUpdated"),
                object: nil,
                userInfo: ["progress": progress]
            )
            try await Task.sleep(for: .milliseconds(10))
        }
        try? context.save()
    }
    
    private func convertToHKWorkoutActivityType(_ type: WorkoutType) -> HKWorkoutActivityType {
        switch type {
        case .strength:
            return .traditionalStrengthTraining
        case .cardio:
            return .mixedCardio
        case .yoga:
            return .yoga
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .other:
            return .other
        }
    }
    
    private func convertFromHKWorkoutActivityType(_ type: HKWorkoutActivityType) -> WorkoutType {
        switch type {
        case .traditionalStrengthTraining:
            return .strength
        case .mixedCardio:
            return .cardio
        case .yoga:
            return .yoga
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        default:
            return .other
        }
    }
    
    func createDefaultWorkout() async throws {
        // Create a workout from 30 minutes ago
        let startDate = Date().addingTimeInterval(-1800) // 30 minutes ago
        let endDate = Date().addingTimeInterval(-300) // 5 minutes ago
        let duration = endDate.timeIntervalSince(startDate)
        
        // Create the workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        
        // Create the workout
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 250),
            totalDistance: nil,
            metadata: [
                "isDefaultWorkout": true
            ]
        )
        
        // Save the workout to HealthKit
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // Fetch the route (array of CLLocation) for a running workout
    func fetchRoute(for workout: HKWorkout, completion: @escaping ([CLLocation]?) -> Void) {
        print("[HealthKit] fetchRoute called for workout: \(workout.uuid)")
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKSampleQuery(sampleType: routeType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] query, samples, error in
            guard let self = self else { completion(nil); return }
            print("[HealthKit] fetchRoute samples: \(samples?.count ?? -1) for workout: \(workout.uuid)")
            guard let routeSamples = samples as? [HKWorkoutRoute], let route = routeSamples.first else {
                print("[HealthKit] No HKWorkoutRoute samples found for workout \(workout.uuid)")
                completion(nil)
                return
            }
            var locations: [CLLocation] = []
            let locationQuery = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                locations.append(contentsOf: newLocations ?? [])
                if done {
                    print("[HealthKit] Route locations loaded: \(locations.count) points for workout \(workout.uuid)")
                    DispatchQueue.main.async {
                        completion(locations)
                    }
                }
            }
            self.healthStore.execute(locationQuery)
        }
        healthStore.execute(routeQuery)
    }
    
    // Helper: Check authorization status for HKWorkoutRouteType
    func isRouteAuthorized() -> Bool {
        let routeType = HKSeriesType.workoutRoute()
        let status = healthStore.authorizationStatus(for: routeType)
        return status == .sharingAuthorized
    }
}

// Extension to provide a readable name for HKWorkoutActivityType
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .mixedCardio:
            return "Cardio"
        case .yoga:
            return "Yoga"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        default:
            return "Other"
        }
    }
} 