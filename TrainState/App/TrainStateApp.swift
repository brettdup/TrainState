import SwiftUI
import SwiftData
import HealthKit

@main
struct TrainStateApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
} 