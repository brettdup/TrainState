import Foundation
import HealthKit
import CoreLocation
import SwiftData

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var isImporting = false
    
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
        do {
            // Check if we're already importing to prevent concurrent imports
            guard !isImporting else {
                print("[HealthKit] Import already in progress, skipping")
                return
            }
            isImporting = true
            defer { isImporting = false }
            
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

            // Sort by date so progress updates feel consistent
            let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
            print("[HealthKit] Processing \(sortedWorkouts.count) workouts")

            // Pre-fetch existing workouts once to avoid repetitive queries
            let existingWorkouts = try context.fetch(FetchDescriptor<Workout>())
            let existingUUIDs = Set(existingWorkouts.compactMap { $0.healthKitUUID })
            print("[HealthKit] Found \(existingUUIDs.count) existing workouts in database")

            // Create a more robust fuzzy matching system
            struct FuzzyKey: Hashable {
                let type: WorkoutType
                let startBucket: Int
                let durationBucket: Int
                let caloriesBucket: Int?
                let distanceBucket: Int?
            }

            var fuzzySet = Set<FuzzyKey>()
            for workout in existingWorkouts {
                let key = FuzzyKey(
                    type: workout.type,
                    startBucket: Int(workout.startDate.timeIntervalSince1970 / 10), // 10 second buckets
                    durationBucket: Int(workout.duration / 10), // 10 second duration buckets
                    caloriesBucket: workout.calories.map { Int($0 / 10) }, // 10 calorie buckets
                    distanceBucket: workout.distance.map { Int($0 / 50) } // 50 meter buckets
                )
                fuzzySet.insert(key)
            }

            let totalWorkouts = sortedWorkouts.count
            var processedWorkouts = 0
            var newWorkoutsAdded = 0
            var skippedWorkouts = 0
            var runningWorkoutsToRoute: [(hkWorkout: HKWorkout, workout: Workout)] = []

            for hkWorkout in sortedWorkouts {
                let uuid = hkWorkout.uuid
                
                // Skip if we already have this exact workout
                if existingUUIDs.contains(uuid) {
                    skippedWorkouts += 1
                    processedWorkouts += 1
                    continue
                }

                let workoutType = convertFromHKWorkoutActivityType(hkWorkout.workoutActivityType)
                let calories = hkWorkout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
                let distance = hkWorkout.totalDistance?.doubleValue(for: .meter())
                
                // Create fuzzy key for duplicate detection
                let fuzzyKey = FuzzyKey(
                    type: workoutType,
                    startBucket: Int(hkWorkout.startDate.timeIntervalSince1970 / 10),
                    durationBucket: Int(hkWorkout.duration / 10),
                    caloriesBucket: calories.map { Int($0 / 10) },
                    distanceBucket: distance.map { Int($0 / 50) }
                )
                
                // Skip if we have a fuzzy match
                if fuzzySet.contains(fuzzyKey) {
                    skippedWorkouts += 1
                    processedWorkouts += 1
                    continue
                }

                // Create the new workout
                let workout = Workout(
                    type: workoutType,
                    startDate: hkWorkout.startDate,
                    duration: hkWorkout.duration,
                    calories: calories,
                    distance: distance,
                    notes: "Imported from Apple Health",
                    healthKitUUID: uuid
                )

                // Only add running workouts with reasonable duration for route processing
                if hkWorkout.workoutActivityType == .running && hkWorkout.duration > 60 {
                    runningWorkoutsToRoute.append((hkWorkout, workout))
                }

                context.insert(workout)
                fuzzySet.insert(fuzzyKey)
                newWorkoutsAdded += 1

                processedWorkouts += 1
                let progress = Double(processedWorkouts) / Double(totalWorkouts)
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportProgressUpdated"),
                    object: nil,
                    userInfo: ["progress": progress]
                )

                // Save every 10 workouts to prevent memory buildup
                if processedWorkouts % 10 == 0 {
                    try context.save()
                    await Task.yield() // Allow other tasks to run
                }
            }
            
            try context.save()
            
            print("[HealthKit] Import completed - Added: \(newWorkoutsAdded), Skipped: \(skippedWorkouts), Total processed: \(processedWorkouts)")

            // Only process routes if we added new workouts
            if newWorkoutsAdded > 0 {
                // Notify UI that route fetching is starting
                NotificationCenter.default.post(name: NSNotification.Name("ImportRoutesStarted"), object: nil)
                onRoutesStarted?()

                // Fetch routes for running workouts in parallel after main import
                // Limit concurrent route processing to prevent memory issues
                await withTaskGroup(of: Void.self) { group in
                    let maxConcurrentRoutes = 2 // Reduced from 3 to prevent overheating
                    var activeTasks = 0
                    
                    for (hkWorkout, workout) in runningWorkoutsToRoute {
                        // Wait if we have too many active tasks
                        while activeTasks >= maxConcurrentRoutes {
                            await Task.yield()
                        }
                        
                        group.addTask {
                            activeTasks += 1
                            defer { activeTasks -= 1 }
                            
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
                                // Limit the number of location points to prevent memory issues
                                let maxPoints = 500 // Reduced from 1000 to prevent overheating
                                let limitedLocations = locs.count > maxPoints ? Array(locs.prefix(maxPoints)) : locs
                                
                                print("[HealthKit] Saving route data for workout: \(hkWorkout.uuid) with \(limitedLocations.count) points")
                                await MainActor.run {
                                    let uuid = hkWorkout.uuid
                                    let fetch = try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.healthKitUUID == uuid }))
                                    if let dbWorkout = fetch?.first {
                                        do {
                                            // Use a more efficient encoding method for large location arrays
                                            let routeData = try NSKeyedArchiver.archivedData(withRootObject: limitedLocations, requiringSecureCoding: false)
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
            } else {
                print("[HealthKit] No new workouts added, skipping route processing")
            }

            // Notify UI that all import work is complete
            NotificationCenter.default.post(name: NSNotification.Name("ImportAllComplete"), object: nil)
            onAllComplete?()
            
        } catch {
            print("[HealthKit] Import failed with error: \(error.localizedDescription)")
            throw error
        }
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
        
        // Add timeout protection
        let timeoutTask = DispatchWorkItem {
            print("[HealthKit] Route fetch timeout for workout: \(workout.uuid)")
            completion(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutTask)
        
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKSampleQuery(sampleType: routeType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] query, samples, error in
            timeoutTask.cancel() // Cancel timeout if query completes
            
            guard let self = self else { 
                completion(nil)
                return 
            }
            
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
            let maxLocations = 2000 // Limit to prevent memory issues
            
            let locationQuery = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error = error {
                    print("[HealthKit] Error fetching route locations: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                // Add new locations with limit check
                if let newLocs = newLocations {
                    let remainingCapacity = maxLocations - locations.count
                    let locationsToAdd = newLocs.prefix(remainingCapacity)
                    locations.append(contentsOf: locationsToAdd)
                }
                
                if done || locations.count >= maxLocations {
                    print("[HealthKit] Route locations loaded: \(locations.count) points for workout \(workout.uuid)")
                    
                    // Filter out invalid locations
                    let validLocations = locations.filter { location in
                        location.coordinate.latitude != 0 && location.coordinate.longitude != 0 &&
                        location.coordinate.latitude.isFinite && location.coordinate.longitude.isFinite
                    }
                    
                    DispatchQueue.main.async {
                        completion(validLocations.isEmpty ? nil : validLocations)
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
