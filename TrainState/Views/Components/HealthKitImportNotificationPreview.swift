import SwiftUI

/// A visual approximation of the system notification shown after HealthKit imports.
/// This is intentionally presentation-only; the real notification is still created
/// by NotificationManager through UserNotifications.
struct HealthKitImportNotificationPreview: View {
    let title: String
    let subtitle: String
    let notificationBody: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            notificationHeader

            HStack(alignment: .top, spacing: 12) {
                Image("AppIconOriginalPreview")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(notificationBody)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: 430, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). \(notificationBody)")
    }

    private var notificationHeader: some View {
        HStack(spacing: 6) {
            Text("EXERCISE PAL")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)

            Spacer()

            Text("now")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview("Single import · Light") {
    HealthKitImportNotificationPreview(
        title: "Outdoor Run added",
        subtitle: "Today at 7:42 AM · Apple Health",
        notificationBody: "42 min · 5.20 km · 388 kcal"
    )
    .padding(20)
    .background(Color(uiColor: .systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Batch import · Dark") {
    HealthKitImportNotificationPreview(
        title: "Your workout log is up to date",
        subtitle: "Apple Health · 2 new · 1 matched",
        notificationBody: "2 new and 1 matched from Apple Health. Latest: Indoor Cycle · 58 min · 512 kcal."
    )
    .padding(20)
    .background(Color(uiColor: .systemGroupedBackground))
    .preferredColorScheme(.dark)
}
