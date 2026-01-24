import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self], inMemory: true)
}
