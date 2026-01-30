import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var showCelebration = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TabView(selection: $currentPage) {
                        welcomePage.tag(0)
                        quickLogPage.tag(1)
                        appPreviewPage.tag(2)
                        trackProgressPage.tag(3)
                        getStartedPage.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentPage) { _, _ in
                        HapticManager.lightImpact()
                    }

                    backButton
                }

                pageIndicator
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
            .overlay(alignment: .topTrailing) {
                skipButton
                    .zIndex(100)
            }
        }
        .overlay {
            if showCelebration {
                OnboardingCelebrationView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    // MARK: - Back Button

    @ViewBuilder
    private var backButton: some View {
        if currentPage > 0 {
            Button {
                currentPage -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    // MARK: - Skip Button

    @ViewBuilder
    private var skipButton: some View {
        if currentPage < totalPages - 1 {
            Button {
                withAnimation(.easeOut(duration: 0.3)) {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                Color(.systemBackground)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPageContent(
            icon: "figure.run",
            iconColor: Color.accentColor,
            title: "TrainState",
            subtitle: "Your workout companion",
            description: "A clean, focused way to log workouts and watch your progress grow.",
            heroContent: { OnboardingIconHero(icon: "figure.run", iconColor: Color.accentColor, appeared: appeared) },
            appeared: appeared
        )
    }

    private var quickLogPage: some View {
        OnboardingPageContent(
            icon: "plus.circle.fill",
            iconColor: Color.accentColor,
            title: "Log in Seconds",
            subtitle: "Quick & simple",
            description: "Add workouts with type, duration, and distance. Organize with custom categories and subcategories.",
            features: [
                ("Running, strength, yoga & more", "figure.run"),
                ("Duration and distance tracking", "timer"),
                ("Categories for your routine", "tag.fill")
            ],
            heroContent: { OnboardingIconHero(icon: "plus.circle.fill", iconColor: Color.accentColor, appeared: appeared) },
            appeared: appeared
        )
    }

    private var appPreviewPage: some View {
        OnboardingPageContent(
            icon: "iphone",
            iconColor: Color.accentColor,
            title: "Your Home Screen",
            subtitle: "A glimpse inside",
            description: "Log workouts, track limits, and see your weekly progress at a glance.",
            heroContent: {
                OnboardingAppPreview()
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appeared)
            },
            appeared: appeared
        )
    }

    private var trackProgressPage: some View {
        OnboardingPageContent(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: Color.accentColor,
            title: "See Your Progress",
            subtitle: "Stay motivated",
            description: "View weekly totals, browse your calendar, and track how your fitness evolves over time.",
            features: [
                ("Weekly workout summary", "calendar"),
                ("Calendar view of your activity", "calendar.badge.clock"),
                ("Analytics for premium users", "crown.fill")
            ],
            heroContent: { OnboardingIconHero(icon: "chart.line.uptrend.xyaxis", iconColor: Color.accentColor, appeared: appeared) },
            appeared: appeared
        )
    }

    private var getStartedPage: some View {
        OnboardingPageContent(
            icon: "checkmark.circle.fill",
            iconColor: Color.accentColor,
            title: "You're All Set",
            subtitle: "Ready to train",
            description: "Start logging your first workout. Free tier includes 7 workouts, 3 categories, and 2 subcategories per category.",
            heroContent: { OnboardingIconHero(icon: "checkmark.circle.fill", iconColor: Color.accentColor, appeared: appeared) },
            appeared: appeared
        )
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.accentColor : Color.primary.opacity(0.2))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button {
            if currentPage < totalPages - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentPage += 1
                }
            } else {
                HapticManager.success()
                showCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(currentPage < totalPages - 1 ? "Continue" : "Get Started")
                    .fontWeight(.semibold)
                Image(systemName: currentPage < totalPages - 1 ? "arrow.right" : "checkmark")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.accentColor)
            )
            .foregroundStyle(.white)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding Page Content

private struct OnboardingPageContent<HeroContent: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    var features: [(String, String)] = []
    let heroContent: () -> HeroContent
    let appeared: Bool

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        description: String,
        features: [(String, String)] = [],
        @ViewBuilder heroContent: @escaping () -> HeroContent,
        appeared: Bool
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.features = features
        self.heroContent = heroContent
        self.appeared = appeared
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                heroContent()

                VStack(spacing: 8) {
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }

                if !features.isEmpty {
                    featureList
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(features.indices), id: \.self) { index in
                HStack(spacing: 14) {
                    Image(systemName: features[index].1)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(iconColor.opacity(0.12))
                        )

                    Text(features[index].0)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(index) * 0.08),
                    value: appeared
                )
            }
        }
    }
}

// MARK: - Onboarding Icon Hero

private struct OnboardingIconHero: View {
    let icon: String
    let iconColor: Color
    let appeared: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.12))
                .frame(width: 120, height: 120)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Image(systemName: icon)
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [iconColor, iconColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
        }
    }
}

#Preview {
    OnboardingView()
}
