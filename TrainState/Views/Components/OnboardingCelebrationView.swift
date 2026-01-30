import SwiftUI

/// Brief celebration overlay shown when user completes onboarding.
struct OnboardingCelebrationView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .opacity(opacity)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(scale)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)
                        .scaleEffect(checkmarkScale)
                }

                Text("Welcome!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
                checkmarkScale = 1
            }
        }
    }
}

#Preview {
    OnboardingCelebrationView()
}
