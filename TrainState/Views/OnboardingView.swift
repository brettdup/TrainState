import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("TrainState")
                .font(.largeTitle.weight(.semibold))
            Text("A clean log for workouts and progress.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                Label("Log workouts in seconds", systemImage: "checkmark.circle")
                Label("Filter by type", systemImage: "line.3.horizontal.decrease.circle")
                Label("See weekly totals", systemImage: "calendar")
            }
            .font(.subheadline)
            .padding(.top, 12)

            Spacer()
            Button("Get Started") {
                hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    OnboardingView()
}
