import Foundation
import HealthKit
import SwiftData
import CoreLocation

class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private static var isImporting = false
    private var lastImportDate: Date?
    
    // Import rate limiting - 30 seconds between imports for better debugging
    private let importCooldownInterval: TimeInterval = 30
    
    private init() {
        // Check HealthKit availability
        if HKHealthStore.isHealthDataAvailable() {
            print("[HealthKit] HealthKit is available on this device")
        } else {
            print("[HealthKit] HealthKit is NOT available on this device")
        }
    }
    
    // MARK: - Availability Check
    
    func isHealthKitAvailable() -> Bool {
        let available = HKHealthStore.isHealthDataAvailable()
        print("[HealthKit] HealthKit availability check: \(available)")
        return available
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] HealthKit not available")
            throw HealthKitError.healthKitNotAvailable
        }
        
        let workoutType = HKObjectType.workoutType()
        let types: Set = [workoutType]
        
        // Check current status before requesting
        let currentStatus = healthStore.authorizationStatus(for: workoutType)
        print("[HealthKit] Current authorization status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .notDetermined:
            print("[HealthKit] Status is notDetermined, requesting authorization...")
        case .sharingDenied:
            print("[HealthKit] Previously denied, but attempting request anyway...")
        case .sharingAuthorized:
            print("[HealthKit] Already authorized!")
            return
        @unknown default:
            print("[HealthKit] Unknown status, attempting request...")
        }
        
        print("[HealthKit] Requesting authorization for workout data...")
        try await healthStore.requestAuthorization(toShare: [], read: types)
        
        // Check status after request
        let newStatus = healthStore.authorizationStatus(for: workoutType)
        print("[HealthKit] Authorization status after request: \(newStatus.rawValue)")
        
        switch newStatus {
        case .notDetermined:
            print("[HealthKit] Still not determined - user may have dismissed dialog")
            throw HealthKitError.notAuthorized
        case .sharingDenied:
            print("[HealthKit] Authorization denied by user")
            throw HealthKitError.permissionDenied
        case .sharingAuthorized:
            print("[HealthKit] Authorization granted!")
        @unknown default:
            print("[HealthKit] Unknown authorization status")
            throw HealthKitError.notAuthorized
        }
    }
    
    func isAuthorized() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] HealthKit not available")
            return false
        }
        
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        let isAuthorized = status == .sharingAuthorized
        
        print("[HealthKit] Authorization check:")
        print("[HealthKit]   Status raw value: \(status.rawValue)")
        print("[HealthKit]   Status description: \(statusDescription(status))")
        print("[HealthKit]   Is authorized: \(isAuthorized)")
        
        return isAuthorized
    }
    
    // Test method to verify actual data access (not just authorization status)
    func testDataAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] HealthKit not available for test")
            return false
        }
        
        print("[HealthKit] Testing actual data access...")
        
        do {
            let workouts = try await fetchHealthKitWorkouts()
            print("[HealthKit] Data access test successful - found \(workouts.count) workouts")
            return true
        } catch {
            print("[HealthKit] Data access test failed: \(error)")
            return false
        }
    }
    
    private func statusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .sharingDenied:
            return "sharingDenied"
        case .sharingAuthorized:
            return "sharingAuthorized"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }
    
    // MARK: - Workout Import
    
    // Replace the old importWorkouts implementation to use a background context for all imports
    func importWorkouts(to mainContext: ModelContext) async throws -> (added: Int, skipped: Int) {
        // Prevent concurrent imports
        guard !Self.isImporting else {
            print("[HealthKit] Import already in progress, skipping")
            throw HealthKitError.importInProgress
        }
        
        // Rate limiting check
        if let lastImport = lastImportDate,
           Date().timeIntervalSince(lastImport) < importCooldownInterval {
            let timeRemaining = importCooldownInterval - Date().timeIntervalSince(lastImport)
            print("[HealthKit] Rate limited, \(Int(timeRemaining)) seconds remaining")
            throw HealthKitError.rateLimited(Int(timeRemaining))
        }
        
        print("[HealthKit] Proceeding with chunked import using background context")
        Self.isImporting = true
        defer { Self.isImporting = false }
        
        // Get the persistent container from the main context
        let container = mainContext.container
        let backgroundContext = ModelContext(container)
        backgroundContext.autosaveEnabled = false
        
        print("[HealthKit] Starting chunked workout import in background context...")
        
        // Use chunked import for all imports (default: all history, chunked by month)
        let result = try await performChunkedImport(to: backgroundContext, timeLimit: nil)
        
        // After import, refresh the main context to pick up new data
        await MainActor.run {
            do {
                try mainContext.save()
            } catch {
                print("[HealthKit] Failed to save main context after import: \(error)")
            }
        }
        return result
    }
    
    // Ultra-simple shared import logic 
    private func performImport(to context: ModelContext, fetchMethod: () async throws -> [HKWorkout]) async throws -> (added: Int, skipped: Int) {
        // Fetch HealthKit workouts using provided method
        let hkWorkouts = try await fetchMethod()
        print("[HealthKit] Found \(hkWorkouts.count) HealthKit workouts")
        
        // Get existing workout signatures ONCE at the start
        let existingWorkouts = try context.fetch(FetchDescriptor<Workout>())
        var existingSignatures = Set<String>()
        
        for workout in existingWorkouts {
            let signature = "\(workout.type.rawValue)-\(Int(workout.startDate.timeIntervalSince1970))-\(Int(workout.duration))"
            existingSignatures.insert(signature)
        }
        
        var addedCount = 0
        var skippedCount = 0
        
        // Process each workout with minimal overhead
        for (index, hkWorkout) in hkWorkouts.enumerated() {
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            
            // Create simple signature for duplicate check
            let workoutType = mapHealthKitWorkoutType(hkWorkout.workoutActivityType)
            let signature = "\(workoutType.rawValue)-\(Int(hkWorkout.startDate.timeIntervalSince1970))-\(Int(hkWorkout.duration))"
            
            // Skip if duplicate
            if existingSignatures.contains(signature) {
                skippedCount += 1
                continue
            }
            
            // Create minimal workout
            let workout = Workout(
                type: workoutType,
                startDate: hkWorkout.startDate,
                duration: hkWorkout.duration,
                calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                notes: "Imported from HealthKit"
            )
            
            context.insert(workout)
            
            do {
                try context.save()
                existingSignatures.insert(signature) // Add to our local cache
                addedCount += 1
                
                if addedCount % 25 == 0 {
                    print("[HealthKit] Progress: \(addedCount) added, \(skippedCount) skipped")
                }
                
            } catch {
                print("[HealthKit] Failed to save workout: \(error)")
                context.delete(workout)
                continue
            }
            
            // Minimal yielding
            if index % 10 == 0 {
                await Task.yield()
            }
        }
        
        print("[HealthKit] Import complete: \(addedCount) added, \(skippedCount) skipped")
        lastImportDate = Date()
        return (added: addedCount, skipped: skippedCount)
    }
    
    // MARK: - HealthKit Data Fetching
    
    private func fetchHealthKitWorkouts(timeLimit: TimeInterval? = nil) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        
        let predicate: NSPredicate
        if let timeLimit = timeLimit {
            // Fetch workouts from specified time period
            let calendar = Calendar.current
            let startDate = calendar.date(byAdding: .second, value: -Int(timeLimit), to: Date()) ?? Date()
            predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
            
            let timeDescription = timeLimit >= 31536000 ? "\(Int(timeLimit / 31536000)) years" : "\(Int(timeLimit / 86400)) days"
            print("[HealthKit] Fetching workouts from \(startDate.formatted()) to now (\(timeDescription) of history)...")
        } else {
            // Fetch ALL workouts (no time limit)
            predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictStartDate)
            print("[HealthKit] Fetching ALL workouts (complete history)...")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("[HealthKit] Query failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                print("[HealthKit] Query returned \(workouts.count) workouts")
                
                // Log summary instead of individual workouts
                let sampleTypes = Array(Set(workouts.prefix(10).map { self.mapHealthKitWorkoutType($0.workoutActivityType).rawValue }))
                print("[HealthKit] Sample workout types: \(sampleTypes.joined(separator: ", "))")
                
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Standard import (2 years)
    private func fetchHealthKitWorkouts() async throws -> [HKWorkout] {
        let twoYears: TimeInterval = 2 * 365 * 24 * 60 * 60 // 2 years in seconds
        return try await fetchHealthKitWorkouts(timeLimit: twoYears)
    }
    
    // Import all workout history with memory safety
    func importAllWorkouts(to context: ModelContext) async throws -> (added: Int, skipped: Int) {
        // Use chunked import to prevent memory crashes
        return try await performChunkedImport(to: context, timeLimit: nil)
    }
    
    // Ultra-simple import - minimal database queries to prevent crashes
    private func performChunkedImport(to context: ModelContext, timeLimit: TimeInterval?) async throws -> (added: Int, skipped: Int) {
        // Calculate the time window
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        if let timeLimit = timeLimit {
            startDate = calendar.date(byAdding: .second, value: -Int(timeLimit), to: now) ?? now
        } else {
            // If no limit, default to 10 years ago
            startDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }

        var totalAdded = 0
        var totalSkipped = 0
        var currentStart = startDate
        var currentEnd: Date

        // Get existing workout signatures ONCE at the start to minimize DB queries
        let existingWorkouts = try context.fetch(FetchDescriptor<Workout>())
        var existingSignatures = Set<String>()
        for workout in existingWorkouts {
            let signature = "\(workout.type.rawValue)-\(Int(workout.startDate.timeIntervalSince1970))-\(Int(workout.duration))"
            existingSignatures.insert(signature)
        }
        print("[HealthKit] Found \(existingSignatures.count) existing workout signatures")

        // Loop over each month in the window
        while currentStart < now {
            currentEnd = calendar.date(byAdding: .month, value: 1, to: currentStart) ?? now
            if currentEnd > now { currentEnd = now }

            // Fetch workouts for this month
            let predicate = HKQuery.predicateForSamples(withStart: currentStart, end: currentEnd, options: .strictStartDate)
            let monthWorkouts = try await fetchHealthKitWorkoutsWithPredicate(predicate)
            print("[HealthKit] Fetched \(monthWorkouts.count) workouts from \(currentStart) to \(currentEnd)")

            for (index, hkWorkout) in monthWorkouts.enumerated() {
                guard !Task.isCancelled else { throw CancellationError() }
                let workoutType = mapHealthKitWorkoutType(hkWorkout.workoutActivityType)
                let signature = "\(workoutType.rawValue)-\(Int(hkWorkout.startDate.timeIntervalSince1970))-\(Int(hkWorkout.duration))"
                if existingSignatures.contains(signature) {
                    totalSkipped += 1
                    continue
                }
                let workout = Workout(
                    type: workoutType,
                    startDate: hkWorkout.startDate,
                    duration: hkWorkout.duration,
                    calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                    distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                    notes: "Imported from HealthKit"
                )
                context.insert(workout)
                do {
                    try context.save()
                    existingSignatures.insert(signature)
                    totalAdded += 1
                    if totalAdded % 50 == 0 {
                        print("[HealthKit] Progress: \(totalAdded) added, \(totalSkipped) skipped (of month \(index + 1)/\(monthWorkouts.count))")
                    }
                } catch {
                    print("[HealthKit] Failed to save workout: \(error)")
                    context.delete(workout)
                    continue
                }
                if index % 10 == 0 { await Task.yield() }
            }
            // Move to next month
            currentStart = currentEnd
            // Let UI/context settle
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        print("[HealthKit] Import complete: \(totalAdded) added, \(totalSkipped) skipped")
        return (added: totalAdded, skipped: totalSkipped)
    }

    // Helper to fetch workouts with a custom predicate (for chunked import)
    private func fetchHealthKitWorkoutsWithPredicate(_ predicate: NSPredicate) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("[HealthKit] Query failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }
    
    // Ultra memory-safe import for individual chunks
    private func performMemorySafeImport(to context: ModelContext, workouts: [HKWorkout]) async throws -> (added: Int, skipped: Int) {
        var addedCount = 0
        var skippedCount = 0
        
        // Process each workout individually with maximum memory safety
        for (index, hkWorkout) in workouts.enumerated() {
            // Check for cancellation on every workout
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            
            // Fresh duplicate check for each workout to prevent context conflicts
            let fuzzyKey = createFuzzyKey(for: hkWorkout)
            
            // Check if this workout already exists (fresh query each time)
            let existingWorkouts = try context.fetch(FetchDescriptor<Workout>())
            let existingWorkoutKeys = Set(existingWorkouts.compactMap { workout in
                createFuzzyKey(for: workout)
            })
            
            // Skip duplicates
            if existingWorkoutKeys.contains(fuzzyKey) {
                skippedCount += 1
                continue
            }
            
            // Convert and save workout immediately (one at a time)
            do {
                let workout = await convertHealthKitWorkoutMinimal(hkWorkout)
                
                // Double-check before insert to prevent duplicate registration
                let preInsertCheck = try context.fetch(FetchDescriptor<Workout>())
                let preInsertKeys = Set(preInsertCheck.compactMap { createFuzzyKey(for: $0) })
                
                if preInsertKeys.contains(fuzzyKey) {
                    print("[HealthKit] Workout already exists, skipping to prevent duplicate registration")
                    skippedCount += 1
                    continue
                }
                
                context.insert(workout)
                addedCount += 1
                
                // Save immediately after each workout to prevent memory buildup
                try context.save()
                
                if addedCount % 25 == 0 {
                    print("[HealthKit] Progress: \(addedCount) added, \(skippedCount) skipped")
                }
                
                // Yield control frequently
                if index % 2 == 0 {
                    await Task.yield()
                }
                
            } catch {
                print("[HealthKit] Failed to convert/save workout: \(error)")
                // Continue with next workout instead of failing entire import
                continue
            }
        }
        
        return (added: addedCount, skipped: skippedCount)
    }
    
    // Minimal workout conversion to reduce memory usage
    private func convertHealthKitWorkoutMinimal(_ hkWorkout: HKWorkout) async -> Workout {
        // Create minimal workout without route data to save memory
        let workout = Workout(
            type: mapHealthKitWorkoutType(hkWorkout.workoutActivityType),
            startDate: hkWorkout.startDate,
            duration: hkWorkout.duration,
            calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
            notes: "Imported from HealthKit"
        )
        
        // No route fetching for large imports - routes use too much memory
        return workout
    }
    
    // MARK: - Workout Conversion
    
    private func convertHealthKitWorkout(_ hkWorkout: HKWorkout) async -> Workout {
        let workout = Workout(
            type: mapHealthKitWorkoutType(hkWorkout.workoutActivityType),
            startDate: hkWorkout.startDate,
            duration: hkWorkout.duration,
            calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
            notes: "Imported from HealthKit"
        )
        
        // Skip route fetching for large imports to prevent memory crashes
        // Route data can be very memory intensive and cause crashes with many workouts
        // Comment: Temporarily disabled for memory safety
        // if hasLocationData(hkWorkout.workoutActivityType) {
        //     await fetchWorkoutRoute(for: hkWorkout, workout: workout)
        // }
        
        return workout
    }
    
    private func fetchWorkoutRoute(for hkWorkout: HKWorkout, workout: Workout) async {
        do {
            let locations = try await fetchWorkoutLocations(for: hkWorkout)
            if !locations.isEmpty {
                // Limit locations to prevent memory issues (max 500 points)
                let limitedLocations = Array(locations.prefix(500))
                let route = WorkoutRoute()
                route.decodedRoute = limitedLocations
                workout.route = route
                print("[HealthKit] Added route with \(limitedLocations.count) points")
            }
        } catch {
            print("[HealthKit] Failed to fetch route: \(error)")
            // Continue without route - don't fail the entire import
        }
    }
    
    private func fetchWorkoutLocations(for hkWorkout: HKWorkout) async throws -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: hkWorkout)
            
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let routeSample = samples?.first as? HKWorkoutRoute else {
                    continuation.resume(returning: [])
                    return
                }
                
                var locations: [CLLocation] = []
                let locationQuery = HKWorkoutRouteQuery(route: routeSample) { _, locationResults, done, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let locationResults = locationResults {
                        locations.append(contentsOf: locationResults)
                    }
                    
                    if done {
                        continuation.resume(returning: locations)
                    }
                }
                
                self.healthStore.execute(locationQuery)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Duplicate Detection
    
    private func createFuzzyKey(for workout: Workout) -> FuzzyKey {
        let timeKey = Int(workout.startDate.timeIntervalSince1970 / 10) // 10-second buckets
        let durationKey = Int(workout.duration / 10) // 10-second buckets
        let caloriesKey = workout.calories.map { Int($0 / 10) } // 10-calorie buckets
        let distanceKey = workout.distance.map { Int($0 / 50) } // 50-meter buckets
        
        return FuzzyKey(
            type: workout.type,
            timeKey: timeKey,
            durationKey: durationKey,
            caloriesKey: caloriesKey,
            distanceKey: distanceKey
        )
    }
    
    private func createFuzzyKey(for hkWorkout: HKWorkout) -> FuzzyKey {
        let timeKey = Int(hkWorkout.startDate.timeIntervalSince1970 / 10)
        let durationKey = Int(hkWorkout.duration / 10)
        
        let caloriesKey: Int?
        if let caloriesValue = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
            caloriesKey = Int(caloriesValue / 10)
        } else {
            caloriesKey = nil
        }
        
        let distanceKey: Int?
        if let distanceValue = hkWorkout.totalDistance?.doubleValue(for: .meter()) {
            distanceKey = Int(distanceValue / 50)
        } else {
            distanceKey = nil
        }
        
        return FuzzyKey(
            type: mapHealthKitWorkoutType(hkWorkout.workoutActivityType),
            timeKey: timeKey,
            durationKey: durationKey,
            caloriesKey: caloriesKey,
            distanceKey: distanceKey
        )
    }
    
    // MARK: - Helper Methods
    
    private func mapHealthKitWorkoutType(_ hkType: HKWorkoutActivityType) -> WorkoutType {
        switch hkType {
        case .running, .walking:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .yoga:
            return .yoga
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return .strength
        case .mixedCardio, .stairClimbing, .elliptical, .rowing:
            return .cardio
        default:
            return .other
        }
    }
    
    private func hasLocationData(_ activityType: HKWorkoutActivityType) -> Bool {
        switch activityType {
        case .running, .walking, .cycling, .hiking:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

struct FuzzyKey: Hashable {
    let type: WorkoutType
    let timeKey: Int
    let durationKey: Int
    let caloriesKey: Int?
    let distanceKey: Int?
}

enum HealthKitError: LocalizedError {
    case notAuthorized
    case importInProgress
    case rateLimited(Int)
    case healthKitNotAvailable
    case permissionDenied
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "HealthKit access not authorized. Please enable in Settings > Privacy & Security > Health > TrainState."
        case .importInProgress:
            return "An import is already in progress. Please wait for it to complete."
        case .rateLimited(let seconds):
            return "Please wait \(seconds) seconds before importing again."
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device (iOS Simulator or unsupported device)."
        case .permissionDenied:
            return "HealthKit permission was denied. Please go to Settings > Privacy & Security > Health > TrainState and enable 'Workouts' access."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - Array Extension for Batching

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}