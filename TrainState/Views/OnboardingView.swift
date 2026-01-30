import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
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

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "figure.run")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 10) {
                    Text("TrainState")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("A clean log for workouts and progress.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Log workouts quickly", systemImage: "checkmark.circle.fill")
                    Label("Filter by type", systemImage: "line.3.horizontal.decrease.circle.fill")
                    Label("See weekly totals", systemImage: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    hasCompletedOnboarding = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                        Text("Get Started")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
