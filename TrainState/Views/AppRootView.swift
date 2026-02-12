import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var accentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRaw) ?? .blue
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(themeMode.colorScheme)
        .tint(accentColor.color)
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}
