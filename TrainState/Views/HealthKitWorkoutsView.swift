import SwiftUI
import HealthKit
import SwiftData

struct HealthKitWorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var healthKitWorkouts: [HKWorkout] = []
    @State private var importedStatus: [UUID: Bool] = [:] // To track imported status
    private let healthStore = HKHealthStore()

    var body: some View {
        NavigationView {
            List {
                ForEach(healthKitWorkouts, id: \.uuid) { workout in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(workout.workoutActivityType.localizedName)
                                .font(.headline)
                            Text("Duration: \(formatDuration(workout.duration))")
                            Text("Date: \(workout.startDate, style: .date)")
                        }
                        Spacer()
                        if importedStatus[workout.uuid] ?? false {
                            Text("Imported")
                                .foregroundColor(.green)
                        } else {
                            Button("Import") {
                                Task { // Call async importWorkout in a Task
                                    await importWorkout(hkWorkout: workout)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("HealthKit Workouts")
            .onAppear {
                Task {
                    await requestAuthorizationAndFetch()
                }
            }
            .refreshable {
                Task {
                    await checkImportedStatus()
                }
            }
        }
    }

    private func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available.")
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await fetchAllHealthKitWorkouts()
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    private func fetchAllHealthKitWorkouts() async {
        print("Fetching all workouts from HealthKit...")
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // Predicate to fetch all workouts, adjust if needed (e.g., for a specific date range)
        let predicate = HKQuery.predicateForWorkouts(with: .greaterThanOrEqualTo, duration: 0) // Fetches all workouts

        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching HealthKit workouts: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            Task { @MainActor in
                self.healthKitWorkouts = workouts
                print("Fetched \(workouts.count) workouts from HealthKit.")
                await checkImportedStatus()
            }
        }
        healthStore.execute(query)
    }

    private func checkImportedStatus() async {
        print("Checking imported status for HealthKit workouts...")
        var statusDict: [UUID: Bool] = [:]
        for hkWorkout in healthKitWorkouts {
            let workoutUUID = hkWorkout.uuid
            // Convert UUID to string for comparison to avoid type issues
            let uuidString = workoutUUID.uuidString
            let workoutStartDate = hkWorkout.startDate
            let workoutDuration = hkWorkout.duration
            
            let fetchDescriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { $0.healthKitUUID != nil && $0.healthKitUUID!.uuidString == uuidString }
            )
            do {
                let existing = try modelContext.fetch(fetchDescriptor)
                statusDict[workoutUUID] = !existing.isEmpty
            } catch {
                print("Error checking SwiftData for workout UUID \(workoutUUID): \(error.localizedDescription)")
                statusDict[workoutUUID] = false // Assume not imported on error
            }
        }
        Task { @MainActor in
            self.importedStatus = statusDict
            print("Finished checking imported status.")
        }
    }

    private func importWorkout(hkWorkout: HKWorkout) async {
        print("[UI] Calling unified HealthKit import logic from HealthKitWorkoutsView.importWorkout")
        do {
            try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
            // After import, update imported status
            await checkImportedStatus()
        } catch {
            print("[UI] Error importing workouts from HealthKit: \(error.localizedDescription)")
        }
    }

    // New async function to fetch energy burned using modern HealthKit API
    private func fetchEnergyBurned(for workout: HKWorkout) async -> Double? {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            print("Active energy burned type not available for HealthKit query.")
            return nil
        }
        let predicate = HKQuery.predicateForObjects(from: workout)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: energyType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else {
                    print("Error fetching energy samples for workout \(workout.uuid): \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: nil)
                    return
                }
                let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.kilocalorie()) }
                print("Fetched energy for workout \(workout.uuid): \(total) kcal")
                continuation.resume(returning: total)
            }
            healthStore.execute(query)
        }
    }

    // You'll need this mapping function, similar to the one in WorkoutListView
    // Or, ideally, move it to a shared location if used in multiple places.
    private func mapHKWorkoutActivityTypeToWorkoutType(_ activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .yoga:
            return .yoga
        case .barre, .coreTraining, .dance, .flexibility, .highIntensityIntervalTraining, .jumpRope, .kickboxing, .pilates, .stairs, .stepTraining, .walking, .elliptical, .handCycling:
            return .cardio
        // Add more cases as needed for your app
        default:
            print("Unmapped HKWorkoutActivityType in HealthKitWorkoutsView: \(activityType.rawValue) - \(activityType.localizedName)") // Ensure this uses localizedName
            return .other
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// New struct to centralize workout activity naming
struct WorkoutActivityNamer {
    static func name(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .americanFootball: return "American Football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian Football"
        case .badminton: return "Badminton"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing" // Includes Kickboxing
        case .climbing: return "Climbing"
        case .crossTraining: return "Cross Training" // E.g., bootcamp
        case .curling: return "Curling"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        // case .danceInspiredTraining: return "Dance Inspired Training" // (deprecated)
        case .elliptical: return "Elliptical"
        case .equestrianSports: return "Equestrian Sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handball: return "Handball"
        case .hiking: return "Hiking"
        case .hockey: return "Hockey" // E.g., ice hockey, field hockey
        case .hunting: return "Hunting"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial Arts"
        case .mindAndBody: return "Mind and Body" // E.g., tai chi, qigong
        case .mixedMetabolicCardioTraining: return "Mixed Cardio" // (deprecated - use .mixedCardio or .highIntensityIntervalTraining)
        case .paddleSports: return "Paddle Sports" // E.g., canoeing, kayaking, paddle boarding
        case .play: return "Play" // E.g., frisbee, dodgeball, hopscotch, playground activities
        case .preparationAndRecovery: return "Preparation and Recovery" // E.g., foam rolling, stretching
        case .racquetball: return "Racquetball"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .running: return "Running"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating Sports" // E.g., ice skating, inline skating
        case .snowSports: return "Snow Sports" // E.g., skiing, snowboarding, snowshoeing
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .stairClimbing: return "Stair Climbing" // (deprecated - use .stairs)
        case .surfingSports: return "Surfing Sports"
        case .swimming: return "Swimming"
        case .tableTennis: return "Table Tennis"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track and Field" // E.g., sprints, throws, jumps
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .volleyball: return "Volleyball"
        case .walking: return "Walking"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports" // E.g., water skiing, wakeboarding
        case .wrestling: return "Wrestling"
        case .yoga: return "Yoga"

        // iOS 10
        case .barre: return "Barre" // (Pilates, ballet, yoga)
        case .coreTraining: return "Core Training"
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .downhillSkiing: return "Downhill Skiing"
        case .flexibility: return "Flexibility"
        case .highIntensityIntervalTraining: return "HIIT"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .snowboarding: return "Snowboarding"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .wheelchairWalkPace: return "Wheelchair Walk Pace"
        case .wheelchairRunPace: return "Wheelchair Run Pace"

        // iOS 11
        case .taiChi: return "Tai Chi"
        case .mixedCardio: return "Mixed Cardio" // Replaces .mixedMetabolicCardioTraining
        case .handCycling: return "Hand Cycling"

        // iOS 13
        case .discSports: return "Disc Sports"
        case .fitnessGaming: return "Fitness Gaming"

        // iOS 14
        case .cardioDance: return "Cardio Dance"
        case .socialDance: return "Social Dance" // E.g., folk, swing
        case .pickleball: return "Pickleball"
        case .cooldown: return "Cooldown" // E.g., light cool down stretching, meditation

        // iOS 16
        case .swimBikeRun: return "Swim Bike Run" // Triathlon, Duathlon
        case .transition: return "Transition" // Part of a multi-sport workout

        // iOS 17
        case .underwaterDiving: return "Underwater Diving"

        default:
            // Attempt to provide a somewhat descriptive fallback
            // This might require more sophisticated handling for future-proofing
            // or if you want to show the rawValue for truly unknown types.
            let rawString = String(describing: activityType)
            if rawString.contains(".") { // e.g., HKWorkoutActivityType.other
                 return rawString.components(separatedBy: ".").last?.capitalized ?? "Other Workout"
            }
            return "Other Workout (\(activityType.rawValue))" // Fallback using rawValue
        }
    }
}

// Extension to HKWorkoutActivityType to get a user-friendly name
extension HKWorkoutActivityType {
    var localizedName: String { // Ensure this is localizedName
        return WorkoutActivityNamer.name(for: self)
    }
}

struct HealthKitWorkoutsView_Previews: PreviewProvider {
    static var previews: some View {
        HealthKitWorkoutsView()
            // You'll need a model container for previewing if your Workout model is a SwiftData @Model
            .modelContainer(for: Workout.self, inMemory: true)
    }
} 
