import SwiftUI
import SwiftData
import HealthKit

@main
struct TrainStateApp: App {
    let modelContainer: ModelContainer
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        do {
            modelContainer = try ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(modelContainer)
    }
} 