import SwiftUI
import SwiftData
import HealthKit

@main
struct TrainStateApp: App {
    let modelContainer: ModelContainer
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        do {
            // Create a schema with all model types
            let schema = Schema([
                Workout.self,
                WorkoutCategory.self,
                WorkoutSubcategory.self,
                UserSettings.self,
                WorkoutRoute.self
            ])
            
            // Try CloudKit configuration first
            do {
                let bundleIdentifier = Bundle.main.bundleIdentifier ?? "bb.TrainState"
                print("[App] Attempting to initialize CloudKit with bundle identifier: \(bundleIdentifier)")
                
                // Configure CloudKit with more robust settings
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    url: URL.documentsDirectory.appendingPathComponent("TrainState.store"),
                    allowsSave: true,
                    cloudKitDatabase: .private("iCloud.\(bundleIdentifier)"),
                    cloudKitContainerIdentifier: "iCloud.\(bundleIdentifier)"
                )
                
                // Add migration options for better data handling
                cloudConfig.migrationOptions = .destructive
                
                modelContainer = try ModelContainer(for: schema, configurations: cloudConfig)
                print("[App] Successfully initialized ModelContainer with CloudKit")
                
                // Verify CloudKit status
                Task {
                    do {
                        let status = try await CloudKitManager.shared.checkCloudStatus()
                        print("[App] CloudKit status check: \(status ? "Available" : "Unavailable")")
                    } catch {
                        print("[App] CloudKit status check failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                print("[App] CloudKit initialization failed with error: \(error)")
                // Fallback to local-only persistent store
                print("[App] Falling back to local storage")
                let localConfig = ModelConfiguration(
                    schema: schema,
                    url: URL.documentsDirectory.appendingPathComponent("TrainState.store"),
                    allowsSave: true
                )
                modelContainer = try ModelContainer(for: schema, configurations: localConfig)
                print("[App] Successfully initialized ModelContainer with local storage")
            }
        } catch {
            print("Failed to initialize persistent ModelContainer: \(error)")
            // Final fallback to in-memory store
            do {
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
                    configurations: fallbackConfig
                )
                print("Using in-memory ModelContainer as fallback")
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
        
        // Make the tab bar transparent globally and customize item appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.clear

        // Customize item appearance
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = .systemBlue
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 12, weight: .bold)
        ]
        itemAppearance.normal.iconColor = .gray
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray,
            .font: UIFont.systemFont(ofSize: 12, weight: .regular)
        ]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(modelContainer)
        }
    }
} 
