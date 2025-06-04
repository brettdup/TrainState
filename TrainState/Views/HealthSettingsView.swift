import SwiftUI
import HealthKit
import SwiftData

struct HealthSettingsView: View {
    @State private var isHealthKitAuthorized = false
    @State private var isLoadingAuthStatus = true
    @State private var isImporting = false
    @State private var importProgress = 0.0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var exportEnabled = false
    @State private var importEnabled = true
    @State private var lastSyncDate: Date?
    
    @Environment(\.modelContext) private var modelContext
    
    private let healthKitManager = HealthKitManager()
    
    var body: some View {
        Form {
            Section(header: Text("Health Integration Status")) {
                if isLoadingAuthStatus {
                    HStack {
                        ProgressView()
                        Text("Checking authorization status...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: isHealthKitAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isHealthKitAuthorized ? .green : .red)
                        Text(isHealthKitAuthorized ? "Connected to Apple Health" : "Not connected to Apple Health")
                    }
                    
                    if !isHealthKitAuthorized {
                        Button("Connect to Apple Health") {
                            requestHealthKitAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            if isHealthKitAuthorized {
                Section(header: Text("Sync Options")) {
                    Toggle("Import workouts from Health", isOn: $importEnabled)
                    Toggle("Export workouts to Health", isOn: $exportEnabled)
                    
                    if let lastSync = lastSyncDate {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: syncWithHealthKit) {
                        if isImporting {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Syncing...")
                            }
                        } else {
                            Text("Sync Now")
                        }
                    }
                    .disabled(isImporting)
                }
                
                Section(header: Text("Import History")) {
                    Button("Import Past Workouts") {
                        importWorkouts()
                    }
                    .disabled(isImporting)
                    
                    Button("Import All Unimported Workouts") {
                        importUnimportedWorkouts()
                    }
                    .disabled(isImporting)
                    
                    if isImporting {
                        VStack {
                            ProgressView(value: importProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            Text("\(Int(importProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: HealthKitWorkoutsView()) {
                        Text("Browse HealthKit Workouts")
                    }
                }
            }
            
            Section(header: Text("About Health Integration")) {
                Text("TrainState can sync your workouts with Apple Health. This allows you to keep all your fitness data in one place.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Health Integration")
        .onAppear {
            checkHealthKitAuthorizationStatus()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func checkHealthKitAuthorizationStatus() {
        isLoadingAuthStatus = true
        
        Task {
            do {
                let status = try await healthKitManager.checkAuthorizationStatusAsync()
                await MainActor.run {
                    isHealthKitAuthorized = status
                    isLoadingAuthStatus = false
                }
            } catch {
                await MainActor.run {
                    isHealthKitAuthorized = false
                    isLoadingAuthStatus = false
                    errorMessage = "Failed to check HealthKit authorization: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func requestHealthKitAuthorization() {
        Task {
            do {
                let success = try await healthKitManager.requestAuthorizationAsync()
                await MainActor.run {
                    isHealthKitAuthorized = success
                    if !success {
                        errorMessage = "HealthKit authorization was denied. You can enable it in Settings app."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to request HealthKit authorization: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func importWorkouts() {
        guard !isImporting else { return }
        
        isImporting = true
        importProgress = 0.0
        
        Task {
            do {
                try await healthKitManager.importWorkoutsToCoreData(context: modelContext)
                
                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to import workouts: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func importUnimportedWorkouts() {
        guard !isImporting else { return }
        
        isImporting = true
        importProgress = 0.0
        
        Task {
            do {
                // First, request authorization
                let success = try await healthKitManager.requestAuthorizationAsync()
                if !success {
                    errorMessage = "Please enable HealthKit access in Settings to import workouts"
                    showError = true
                    isImporting = false
                    return
                }
                
                // Fetch all workouts from HealthKit
                let healthStore = HKHealthStore()
                let workoutType = HKObjectType.workoutType()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                    let query = HKSampleQuery(
                        sampleType: workoutType,
                        predicate: nil,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: [sortDescriptor]
                    ) { _, samples, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        let workouts = samples as? [HKWorkout] ?? []
                        continuation.resume(returning: workouts)
                    }
                    healthStore.execute(query)
                }
                
                // Get all existing workout UUIDs in a single query
                let fetchDescriptor = FetchDescriptor<Workout>(
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                )
                let existingWorkouts = try modelContext.fetch(fetchDescriptor)
                let existingUUIDs = Set(existingWorkouts.compactMap { $0.healthKitUUID })
                
                // Filter out already imported workouts
                let unimportedWorkouts = workouts.filter { !existingUUIDs.contains($0.uuid) }
                
                // Process workouts in batches
                let batchSize = 20
                let totalBatches = (unimportedWorkouts.count + batchSize - 1) / batchSize
                
                for batchIndex in 0..<totalBatches {
                    let startIndex = batchIndex * batchSize
                    let endIndex = min(startIndex + batchSize, unimportedWorkouts.count)
                    let batchWorkouts = unimportedWorkouts[startIndex..<endIndex]
                    
                    // Create and insert workouts for this batch
                    for workout in batchWorkouts {
                        let newWorkoutType = mapHKWorkoutActivityTypeToWorkoutType(workout.workoutActivityType)
                        
                        let newWorkout = Workout(
                            type: newWorkoutType,
                            startDate: workout.startDate,
                            duration: workout.duration,
                            calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                            distance: workout.workoutActivityType == .running ? workout.totalDistance?.doubleValue(for: .meter()) : nil,
                            healthKitUUID: workout.uuid
                        )
                        
                        modelContext.insert(newWorkout)
                    }
                    
                    // Save after each batch
                    try modelContext.save()
                    
                    // Update progress on main thread
                    await MainActor.run {
                        importProgress = Double(endIndex) / Double(unimportedWorkouts.count)
                    }
                }
                
                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to import workouts: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
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
        default:
            return .other
        }
    }
    
    private func syncWithHealthKit() {
        guard !isImporting else { return }
        
        isImporting = true
        
        Task {
            do {
                if importEnabled {
                    try await healthKitManager.importWorkoutsToCoreData(context: modelContext)
                }
                
                if exportEnabled {
                    // This would call a method to export workouts to HealthKit
                    // try await healthKitManager.exportWorkoutsToHealthKit(workouts)
                }
                
                await MainActor.run {
                    isImporting = false
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to sync with HealthKit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthSettingsView()
    }
} 