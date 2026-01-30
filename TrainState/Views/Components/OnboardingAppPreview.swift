import SwiftUI

/// Phone mockup showing a simplified app preview for onboarding.
struct OnboardingAppPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 44)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)

            VStack(spacing: 0) {
                notch
                    .padding(.top, 12)

                previewContent
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 200, height: 380)
    }

    private var notch: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black)
            .frame(width: 100, height: 28)
    }

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            previewSummaryCard
            previewLimitsCard
            previewWorkoutRow(icon: "figure.run", title: "Running", subtitle: "45 min · 6.2 km")
            previewWorkoutRow(icon: "dumbbell.fill", title: "Strength", subtitle: "60 min")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("This Week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("3 workouts · 2h 15m")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.8))
        )
    }

    private var previewLimitsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Free Tier")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Workouts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("3/7")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.8))
        )
    }

    private func previewWorkoutRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.8))
        )
    }
}

#Preview {
    OnboardingAppPreview()
        .padding()
}
