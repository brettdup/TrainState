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
        }
        .modelContainer(modelContainer)
    }
} 
