import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        ZStack {
            AppTheme.heroGradient
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                VStack(spacing: 18) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 96, weight: .medium))
                        .foregroundStyle(AppTheme.accentBlue, AppTheme.accentPurple.opacity(0.4))
                    
                    VStack(spacing: 10) {
                        Text("Welcome to TrainState")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                        
                        Text("Track smarter. Recover better. See your progress clearly.")
                            .font(.title3.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "chart.bar.fill",
                        title: "Progress at a glance",
                        subtitle: "Calendar, trends, and milestones to keep you moving."
                    )
                    FeatureRow(
                        icon: "heart.text.square.fill",
                        title: "Health-aware sync",
                        subtitle: "Import workouts safely with cellular protection baked in."
                    )
                    FeatureRow(
                        icon: "sparkles",
                        title: "Tailored to you",
                        subtitle: "Custom categories, notes, and reminders you control."
                    )
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.9))
                .background(.ultraThinMaterial.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.05))
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button(action: { hasCompletedOnboarding = true }) {
                    HStack(spacing: 10) {
                        Text("Get Started")
                            .font(.headline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.accentBlue.opacity(0.4), radius: 16, y: 10)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear { print("[Onboarding] OnboardingView appeared") }
    }
}

#Preview {
    OnboardingView()
}
