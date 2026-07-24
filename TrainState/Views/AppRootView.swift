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
                    PremiumStatusLoadingView(
                        accentColor: accentColor.color,
                        appIconImageName: currentAppIcon.previewImageName
                    )
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

    private var currentAppIcon: AppIconOption {
        AppIconOption.option(for: AppIconManager.shared.getCurrentAppIcon())
    }
}

private struct PremiumStatusLoadingView: View {
    let accentColor: Color
    let appIconImageName: String

    var body: some View {
        ZStack {
            ThemeColor.primaryUi01()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: ViewConstants.spacingLarge) {
                    appIcon

                    Text("Exercise Pal")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(ThemeColor.primaryText01())
                }

                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(accentColor)

                    Text("Preparing your training…")
                        .font(.footnote)
                        .foregroundStyle(ThemeColor.primaryText02())
                }
            }
            .offset(y: -24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Exercise Pal is preparing your training")
    }

    private var appIcon: some View {
        Image(appIconImageName)
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, UserSettings.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}

#Preview("Loading") {
    PremiumStatusLoadingView(
        accentColor: AppAccentColor.blue.color,
        appIconImageName: "AppIconOriginalPreview"
    )
}
