import RevenueCat
import SwiftUI
import SwiftData

@main
struct TrainStateApp: App {
    let modelContainer: ModelContainer
    
    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: "appl_xnTHZbPZoGFCkflYbEVudRpmSUo")
        
        // Use persistent storage with clean database setup
        do {
            print("[App] Initializing with persistent storage")
            let schema = Schema([
                Workout.self,
                WorkoutCategory.self,
                WorkoutSubcategory.self,
                UserSettings.self,
                WorkoutRoute.self,
                WorkoutExercise.self,
                WorkoutSubcategoryRating.self,
                SubcategoryExercise.self,
                StrengthWorkoutTemplate.self,
                StrengthWorkoutTemplateExercise.self
            ])
            
            // Use persistent database that preserves all data
            let storeURL = URL.documentsDirectory.appendingPathComponent("ExercisePalWorkoutTracker.store")
            
            let config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
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
                    WorkoutRoute.self,
                    WorkoutExercise.self,
                    WorkoutSubcategoryRating.self,
                    SubcategoryExercise.self,
                    StrengthWorkoutTemplate.self,
                    StrengthWorkoutTemplateExercise.self
                ])
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: config)
                print("[App] Using in-memory fallback")
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
        
        DataInitializationManager.shared.initializeAppData(context: modelContainer.mainContext)
        let container = self.modelContainer
        Task { @MainActor in
            WatchHealthKitSyncBridge.shared.start(modelContainer: container)
            if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
               UserDefaults.standard.bool(forKey: "hasRequestedOnboardingHealthKitAccess") {
                await HealthKitWorkoutAutoImportService.shared.start(modelContainer: container)
            }
        }
        print("[App] App initialization completed")
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
            .modelContainer(modelContainer)
            .onAppear {
                print("[App] App body appeared successfully")
            }
        }
    }
} 
