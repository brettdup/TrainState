import SwiftUI
import SwiftData

@main
struct TrainStateApp: App {
    let modelContainer: ModelContainer
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Use persistent storage with clean database setup
        do {
            print("[App] Initializing with persistent storage")
            let schema = Schema([
                Workout.self,
                WorkoutCategory.self,
                WorkoutSubcategory.self,
                UserSettings.self,
                WorkoutRoute.self
            ])
            
            // Use persistent database that preserves all data
            let storeURL = URL.documentsDirectory.appendingPathComponent("TrainState.store")
            
            let config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
            modelContainer = try ModelContainer(for: schema, configurations: config)
            print("[App] Successfully initialized persistent ModelContainer")
        } catch {
            print("[App] Persistent storage failed, falling back to in-memory")
            do {
                let schema = Schema([
                    Workout.self,
                    WorkoutCategory.self,
                    WorkoutSubcategory.self,
                    UserSettings.self,
                    WorkoutRoute.self
                ])
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: config)
                print("[App] Using in-memory fallback")
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
        
        print("[App] App initialization completed")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(modelContainer)
            .onAppear {
                print("[App] App body appeared successfully")
            }
        }
    }
    
    // MARK: - Migration
    
    @MainActor
    private func performWorkoutTypeMigration() async {
        let migrationKey = "workoutTypeMigrationV3"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return // Migration already completed
        }
        
        do {
            let context = modelContainer.mainContext
            let workouts = try context.fetch(FetchDescriptor<Workout>())
            
            print("[Migration] Found \(workouts.count) workouts")
            
            var fixedCount = 0
            for workout in workouts {
                print("[Migration] Workout: typeRawValue='\(workout.typeRawValue)', notes='\(workout.notes ?? "none")'")
                
                // If typeRawValue is empty but the workout should have a type, try to fix it
                if workout.typeRawValue.isEmpty {
                    // Try to determine type from the notes if it says "Imported from Health"
                    if let notes = workout.notes, notes.contains("Imported from Health") {
                        // This is likely a HealthKit import, let's set it to a reasonable default
                        // We can't determine the original type, so set it to "Other" properly
                        workout.typeRawValue = WorkoutType.other.rawValue
                        fixedCount += 1
                        print("[Migration] Fixed workout with empty typeRawValue")
                    } else {
                        // This is likely a manually created workout, set to "Other"
                        workout.typeRawValue = WorkoutType.other.rawValue
                        fixedCount += 1
                        print("[Migration] Fixed manual workout with empty typeRawValue")
                    }
                }
            }
            
            if fixedCount > 0 {
                try context.save()
                print("[Migration] Fixed \(fixedCount) workouts")
            }
            
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("[Migration] Workout type migration completed")
            
        } catch {
            print("[Migration] Migration failed: \(error)")
        }
    }
} 
