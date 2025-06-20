import Foundation
import HealthKit
import CoreLocation
import SwiftData

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
    
    func importWorkoutsToCoreData(context: ModelContext, onRoutesStarted: (() -> Void)? = nil, onAllComplete: (() -> Void)? = nil) async throws {
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

        // Import all workouts, sorted by startDate descending
        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        print("[HealthKit] Importing all \(sortedWorkouts.count) workouts")

        let totalWorkouts = sortedWorkouts.count
        var processedWorkouts = 0
        var runningWorkoutsToRoute: [(hkWorkout: HKWorkout, workout: Workout)] = []

        // Enhanced tolerance for time and duration comparison (more lenient for CloudKit synced data)
        let timeTolerance: TimeInterval = 5 // 5 seconds
        let durationTolerance: TimeInterval = 5 // 5 seconds

        for hkWorkout in sortedWorkouts {
            print("[HealthKit] Importing workout: \(hkWorkout.uuid) type: \(hkWorkout.workoutActivityType.rawValue) name: \(hkWorkout.workoutActivityType.name)")
            var distance: Double? = nil
            distance = hkWorkout.totalDistance?.doubleValue(for: .meter())

            // Enhanced deduplication: check for both healthKitUUID and fuzzy match on startDate/duration/type
            let uuid = hkWorkout.uuid
            let startDate = hkWorkout.startDate
            let duration = hkWorkout.duration
            
            // First check by healthKitUUID (most reliable)
            let existingByUUID = try? context.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.healthKitUUID == uuid })
            )
            if existingByUUID?.isEmpty == false {
                print("[HealthKit] Skipping duplicate workout by UUID: \(hkWorkout.uuid)")
                continue
            }
            
            // Second check by fuzzy match (startDate, duration, type) for workouts that might not have healthKitUUID
            // This is crucial for CloudKit-synced workouts that may have been restored without healthKitUUID
            let workoutType = convertFromHKWorkoutActivityType(hkWorkout.workoutActivityType)
            let startDateLower = startDate.addingTimeInterval(-timeTolerance)
            let startDateUpper = startDate.addingTimeInterval(timeTolerance)
            let durationLower = duration - durationTolerance
            let durationUpper = duration + durationTolerance
            
            // More comprehensive fuzzy matching including optional distance and calories
            let possibleMatches = try? context.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { workout in
                    workout.type == workoutType &&
                    workout.startDate >= startDateLower && workout.startDate <= startDateUpper &&
                    workout.duration >= durationLower && workout.duration <= durationUpper
                })
            )
            
            let fuzzyMatch = possibleMatches?.first(where: { candidate in
                // Time and duration match
                let timeMatch = abs(candidate.startDate.timeIntervalSince1970 - startDate.timeIntervalSince1970) < timeTolerance
                let durationMatch = abs(candidate.duration - duration) < durationTolerance
                
                // Optional: check calories and distance for additional confidence
                var caloriesMatch = true
                if let hkCalories = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                   let candidateCalories = candidate.calories {
                    caloriesMatch = abs(candidateCalories - hkCalories) < 50 // 50 calorie tolerance
                }
                
                var distanceMatch = true
                if let hkDistance = distance, let candidateDistance = candidate.distance {
                    distanceMatch = abs(candidateDistance - hkDistance) < 100 // 100 meter tolerance
                }
                
                return timeMatch && durationMatch && caloriesMatch && distanceMatch
            })
            
            if fuzzyMatch != nil {
                print("[HealthKit] Skipping duplicate workout by enhanced fuzzy match: \(hkWorkout.uuid)")
                // Update the existing workout with healthKitUUID if it doesn't have one
                if fuzzyMatch?.healthKitUUID == nil {
                    fuzzyMatch?.healthKitUUID = uuid
                    try? context.save()
                    print("[HealthKit] Updated existing workout with healthKitUUID: \(uuid)")
                }
                continue
            }

            let workout = Workout(
                type: workoutType,
                startDate: hkWorkout.startDate,
                duration: hkWorkout.duration,
                calories: hkWorkout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
                distance: distance,
                notes: "Imported from Apple Health",
                healthKitUUID: uuid
            )

            if hkWorkout.workoutActivityType == .running {
                runningWorkoutsToRoute.append((hkWorkout, workout))
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

        // Notify UI that route fetching is starting
        NotificationCenter.default.post(name: NSNotification.Name("ImportRoutesStarted"), object: nil)
        onRoutesStarted?()

        // Fetch routes for running workouts in parallel after main import
        await withTaskGroup(of: Void.self) { group in
            for (hkWorkout, workout) in runningWorkoutsToRoute {
                group.addTask {
                    print("[HealthKit] Starting route fetch for workout: \(hkWorkout.uuid)")
                    let locations: [CLLocation]? = await withCheckedContinuation { continuation in
                        self.fetchRoute(for: hkWorkout) { locs in
                            if let locs = locs {
                                print("[HealthKit] Fetched route for workout \(hkWorkout.uuid): \(locs.count) points")
                            } else {
                                print("[HealthKit] No route found for workout \(hkWorkout.uuid)")
                            }
                            continuation.resume(returning: locs)
                        }
                    }
                    
                    if let locs = locations, !locs.isEmpty {
                        print("[HealthKit] Saving route data for workout: \(hkWorkout.uuid)")
                        await MainActor.run {
                            let uuid = hkWorkout.uuid
                            let fetch = try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.healthKitUUID == uuid }))
                            if let dbWorkout = fetch?.first {
                                do {
                                    let routeData = try NSKeyedArchiver.archivedData(withRootObject: locs, requiringSecureCoding: false)
                                    let workoutRoute = WorkoutRoute(routeData: routeData)
                                    dbWorkout.route = workoutRoute
                                    context.insert(workoutRoute)
                                    try context.save()
                                    print("[HealthKit] Successfully saved route data for workout: \(hkWorkout.uuid)")
                                } catch {
                                    print("[HealthKit] Failed to save route data for workout \(hkWorkout.uuid): \(error.localizedDescription)")
                                }
                            } else {
                                print("[HealthKit] Could not find workout in database for UUID: \(hkWorkout.uuid)")
                            }
                        }
                    } else {
                        print("[HealthKit] No route data to save for workout: \(hkWorkout.uuid)")
                    }
                }
            }
        }

        // Notify UI that all import work is complete
        NotificationCenter.default.post(name: NSNotification.Name("ImportAllComplete"), object: nil)
        onAllComplete?()
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
        case .other:
            return .other
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
            if let error = error {
                print("[HealthKit] Error fetching route: \(error.localizedDescription)")
                completion(nil)
                return
            }
            print("[HealthKit] fetchRoute samples: \(samples?.count ?? -1) for workout: \(workout.uuid)")
            guard let routeSamples = samples as? [HKWorkoutRoute], let route = routeSamples.first else {
                print("[HealthKit] No HKWorkoutRoute samples found for workout \(workout.uuid)")
                completion(nil)
                return
            }
            var locations: [CLLocation] = []
            let locationQuery = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error = error {
                    print("[HealthKit] Error fetching route locations: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
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
