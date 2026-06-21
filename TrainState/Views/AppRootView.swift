import SwiftUI
import SwiftData

struct AppRootView: View {
    @Query private var userSettings: [UserSettings]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue
    @AppStorage("measurementSystem") private var measurementSystemRaw = MeasurementSystem.metric.rawValue
    @StateObject private var purchaseManager = PurchaseManager.shared

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var accentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRaw) ?? .blue
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                if purchaseManager.hasCompletedInitialPremiumCheck {
                    MainTabView()
                } else {
                    premiumStatusLoadingView
                }
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

    private var premiumStatusLoadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(currentAppIcon.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                ProgressView("Loading Exercise Pal…")
                    .tint(accentColor.color)
            }
        }
    }

    private var currentAppIcon: AppIconOption {
        AppIconOption.option(for: AppIconManager.shared.getCurrentAppIcon())
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, UserSettings.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}
