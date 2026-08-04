import UIKit
import UserNotifications

struct HealthKitWorkoutNotificationRenderedAttachment {
    let attachment: UNNotificationAttachment
    let fileURL: URL
}

enum HealthKitWorkoutNotificationAttachmentBuilder {
    static func makeAttachment(
        for detail: HealthKitWorkoutImportNotificationDetail
    ) -> HealthKitWorkoutNotificationRenderedAttachment? {
        let size = CGSize(width: 1200, height: 675)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            drawBackground(in: rendererContext.cgContext, size: size)
            drawIcon(for: detail, in: rendererContext.cgContext)
            drawText(for: detail, in: rendererContext.cgContext, size: size)
            drawMetrics(for: detail, in: rendererContext.cgContext, size: size)
        }

        guard let imageData = image.pngData() else { return nil }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("healthkit-workout-\(UUID().uuidString)")
            .appendingPathExtension("png")

        do {
            try imageData.write(to: fileURL, options: .atomic)
            let attachment = try UNNotificationAttachment(
                identifier: "healthKitWorkoutCard",
                url: fileURL,
                options: nil
            )
            return HealthKitWorkoutNotificationRenderedAttachment(
                attachment: attachment,
                fileURL: fileURL
            )
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            print("[NotificationAttachment] Failed to create attachment: \(error.localizedDescription)")
            return nil
        }
    }

    private static func drawBackground(in context: CGContext, size: CGSize) {
        let colors = [
            UIColor(red: 0.08, green: 0.12, blue: 0.24, alpha: 1).cgColor,
            UIColor(red: 0.12, green: 0.32, blue: 0.42, alpha: 1).cgColor
        ] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        )

        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
    }

    private static func drawIcon(
        for detail: HealthKitWorkoutImportNotificationDetail,
        in context: CGContext
    ) {
        let circleRect = CGRect(x: 70, y: 62, width: 104, height: 104)
        context.setFillColor(UIColor.white.withAlphaComponent(0.16).cgColor)
        context.fillEllipse(in: circleRect)

        let icon = UIImage(systemName: detail.systemImageName)
            ?? UIImage(systemName: "figure.run")
        icon?.withTintColor(.white, renderingMode: .alwaysOriginal)
            .draw(in: circleRect.insetBy(dx: 25, dy: 25))
    }

    private static func drawText(
        for detail: HealthKitWorkoutImportNotificationDetail,
        in context: CGContext,
        size: CGSize
    ) {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.72),
            .kern: 2.0
        ]
        "APPLE HEALTH".draw(
            at: CGPoint(x: 208, y: 72),
            withAttributes: headerAttributes
        )

        let titleFontSize: CGFloat = detail.workoutName.count > 24 ? 42 : 52
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        detail.workoutName.draw(
            in: CGRect(x: 208, y: 106, width: size.width - 270, height: 80),
            withAttributes: titleAttributes
        )
    }

    private static func drawMetrics(
        for detail: HealthKitWorkoutImportNotificationDetail,
        in context: CGContext,
        size: CGSize
    ) {
        let metrics = metricValues(for: detail)
        let columnWidth = (size.width - 140) / CGFloat(metrics.count)

        for (index, metric) in metrics.enumerated() {
            let x = 70 + CGFloat(index) * columnWidth
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 38, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 21, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.68),
                .kern: 1.2
            ]

            metric.value.draw(
                at: CGPoint(x: x, y: 425),
                withAttributes: valueAttributes
            )
            metric.label.draw(
                at: CGPoint(x: x, y: 478),
                withAttributes: labelAttributes
            )
        }
    }

    private static func metricValues(
        for detail: HealthKitWorkoutImportNotificationDetail
    ) -> [(value: String, label: String)] {
        var metrics: [(value: String, label: String)] = [
            (formatDuration(detail.duration), "DURATION")
        ]

        if let distance = detail.distanceKilometers, distance > 0 {
            metrics.append((String(format: "%.1f km", distance), "DISTANCE"))
        }

        if let calories = detail.calories, calories > 0 {
            metrics.append((String(format: "%.0f kcal", calories), "CALORIES"))
        }

        return metrics
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int((duration / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
