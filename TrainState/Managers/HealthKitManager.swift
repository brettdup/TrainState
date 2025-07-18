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

            // Create optimized fuzzy matching system
            struct FuzzyKey: Hashable {
                let type: WorkoutType
                let startBucket: Int
                let durationBucket: Int
                let caloriesBucket: Int?
                let distanceBucket: Int?
            }

            var fuzzySet = Set<FuzzyKey>()
            // Pre-populate fuzzy set for faster lookups
            for workout in existingWorkouts {
                let key = FuzzyKey(
                    type: workout.type,
                    startBucket: Int(workout.startDate.timeIntervalSince1970 / 15), // Wider buckets for better performance
                    durationBucket: Int(workout.duration / 15), // Wider duration buckets
                    caloriesBucket: workout.calories.map { Int($0 / 25) }, // Wider calorie buckets
                    distanceBucket: workout.distance.map { Int($0 / 100) } // Wider distance buckets
                )
                fuzzySet.insert(key)
            }

            // Filter out workouts we already have first
            let newWorkouts = sortedWorkouts.filter { !existingUUIDs.contains($0.uuid) }
            print("[HealthKit] Found \(newWorkouts.count) new workouts to process")
            
            // Early exit if no new workouts
            if newWorkouts.isEmpty {
                print("[HealthKit] No new workouts to import")
                return
            }

            let totalWorkouts = newWorkouts.count
            var processedWorkouts = 0
            var newWorkoutsAdded = 0
            var skippedWorkouts = 0
            var runningWorkoutsToRoute: [(hkWorkout: HKWorkout, workout: Workout)] = []
            var workoutsToInsert: [Workout] = []
            
            // Process workouts in batches
            let batchSize = 50
            for batch in newWorkouts.chunked(into: batchSize) {
                for hkWorkout in batch {
                    let workoutType = convertFromHKWorkoutActivityType(hkWorkout.workoutActivityType)
                    let calories = hkWorkout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
                    let distance = hkWorkout.totalDistance?.doubleValue(for: .meter())
                    
                    // Create fuzzy key for duplicate detection
                    let fuzzyKey = FuzzyKey(
                        type: workoutType,
                        startBucket: Int(hkWorkout.startDate.timeIntervalSince1970 / 15),
                        durationBucket: Int(hkWorkout.duration / 15),
                        caloriesBucket: calories.map { Int($0 / 25) },
                        distanceBucket: distance.map { Int($0 / 100) }
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
                        healthKitUUID: hkWorkout.uuid
                    )

                    // Only add running workouts with reasonable duration for route processing
                    if hkWorkout.workoutActivityType == .running && hkWorkout.duration > 60 {
                        runningWorkoutsToRoute.append((hkWorkout, workout))
                    }

                    workoutsToInsert.append(workout)
                    fuzzySet.insert(fuzzyKey)
                    newWorkoutsAdded += 1
                    processedWorkouts += 1
                }
                
                // Insert batch of workouts
                for workout in workoutsToInsert {
                    context.insert(workout)
                }
                
                // Save after each batch
                try context.save()
                workoutsToInsert.removeAll()
                
                // Update progress
                let progress = Double(processedWorkouts) / Double(totalWorkouts)
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportProgressUpdated"),
                    object: nil,
                    userInfo: ["progress": progress]
                )
                
                // Allow other tasks to run
                await Task.yield()
            }
            
            print("[HealthKit] Import completed - Added: \(newWorkoutsAdded), Skipped: \(skippedWorkouts), Total processed: \(processedWorkouts)")

            // Only process routes if we added new workouts
            if newWorkoutsAdded > 0 {
                // Notify UI that route fetching is starting
                NotificationCenter.default.post(name: NSNotification.Name("ImportRoutesStarted"), object: nil)
                onRoutesStarted?()

                // Fetch routes for running workouts with improved concurrency
                await processWorkoutRoutes(runningWorkoutsToRoute, context: context)
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
    
    // Optimized route processing with better concurrency control
    private func processWorkoutRoutes(_ runningWorkouts: [(hkWorkout: HKWorkout, workout: Workout)], context: ModelContext) async {
        // Process routes in smaller batches to prevent memory issues
        let batchSize = 3
        for batch in runningWorkouts.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for (hkWorkout, workout) in batch {
                    group.addTask {
                        await self.processWorkoutRoute(hkWorkout: hkWorkout, workout: workout, context: context)
                    }
                }
            }
            // Brief pause between batches to prevent overheating
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func processWorkoutRoute(hkWorkout: HKWorkout, workout: Workout, context: ModelContext) async {
        print("[HealthKit] Starting route fetch for workout: \(hkWorkout.uuid)")
        
        let locations = await fetchRouteOptimized(for: hkWorkout)
        
        if let locs = locations, !locs.isEmpty {
            // More aggressive point reduction for better performance
            let maxPoints = 300 // Reduced from 500
            let limitedLocations = locs.count > maxPoints ? Array(locs.prefix(maxPoints)) : locs
            
            await MainActor.run {
                do {
                    // Find the workout in the database
                    let uuid = hkWorkout.uuid
                    let fetch = try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.healthKitUUID == uuid }))
                    if let dbWorkout = fetch?.first {
                        // Use JSONEncoder for better performance than NSKeyedArchiver
                        let routeData = try JSONEncoder().encode(limitedLocations.map { RoutePoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) })
                        let workoutRoute = WorkoutRoute(routeData: routeData)
                        dbWorkout.route = workoutRoute
                        context.insert(workoutRoute)
                        try context.save()
                        print("[HealthKit] Successfully saved route data for workout: \(hkWorkout.uuid) with \(limitedLocations.count) points")
                    }
                } catch {
                    print("[HealthKit] Failed to save route data for workout \(hkWorkout.uuid): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func fetchRouteOptimized(for workout: HKWorkout) async -> [CLLocation]? {
        return await withCheckedContinuation { continuation in
            // Reduced timeout for better responsiveness
            let timeoutTask = DispatchWorkItem {
                continuation.resume(returning: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeoutTask)
            
            let routeType = HKSeriesType.workoutRoute()
            let predicate = HKQuery.predicateForObjects(from: workout)
            let routeQuery = HKSampleQuery(sampleType: routeType, predicate: predicate, limit: 1, sortDescriptors: nil) { [weak self] query, samples, error in
                timeoutTask.cancel()
                
                guard let self = self else { 
                    continuation.resume(returning: nil)
                    return 
                }
                
                if let error = error {
                    print("[HealthKit] Error fetching route: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let routeSamples = samples as? [HKWorkoutRoute], let route = routeSamples.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var locations: [CLLocation] = []
                let maxLocations = 1000 // Reduced from 2000
                
                let locationQuery = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                    if let error = error {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    if let newLocs = newLocations {
                        let remainingCapacity = maxLocations - locations.count
                        let locationsToAdd = newLocs.prefix(remainingCapacity)
                        locations.append(contentsOf: locationsToAdd)
                    }
                    
                    if done || locations.count >= maxLocations {
                        // Filter and simplify locations in one pass
                        let validLocations = locations.compactMap { location -> CLLocation? in
                            guard location.coordinate.latitude != 0 && location.coordinate.longitude != 0 &&
                                  location.coordinate.latitude.isFinite && location.coordinate.longitude.isFinite else {
                                return nil
                            }
                            return location
                        }
                        
                        continuation.resume(returning: validLocations.isEmpty ? nil : validLocations)
                    }
                }
                
                self.healthStore.execute(locationQuery)
            }
            healthStore.execute(routeQuery)
        }
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

// Optimized route point structure for JSON encoding
struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
}

// Array chunking extension for batch processing
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
