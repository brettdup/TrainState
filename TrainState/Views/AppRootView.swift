import SwiftUI
import SwiftData

struct AppRootView: View {
    @Query private var userSettings: [UserSettings]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue
    @AppStorage("measurementSystem") private var measurementSystemRaw = MeasurementSystem.metric.rawValue

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
        .onAppear {
            if let settings = userSettings.first {
                measurementSystemRaw = settings.measurementSystem.rawValue
            }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, UserSettings.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}
