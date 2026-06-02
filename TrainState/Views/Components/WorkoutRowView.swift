import SwiftUI
import SwiftData
import HealthKit

enum WorkoutRowStyle: String, CaseIterable {
    case standard = "Standard"
    case stacked = "Stacked"
    case split = "Split"
    case leading = "Leading"
    case compact = "Compact"
    
}

struct WorkoutRowView: View {
    let workout: Workout
    var style: WorkoutRowStyle = .standard
    var showsChevron: Bool = true

    var body: some View {
        switch style {
        case .standard:
            standardLayout
        case .stacked:
            stackedLayout
        case .split:
            splitLayout
        case .leading:
            leadingLayout
        case .compact:
            compactLayout
        }
    }

    // MARK: - Standard Layout (Icon left, content middle, stats right)
    private var standardLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            iconView(size: 40, iconSize: 18, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 8) {
                workoutTitle(font: .headline, lineLimit: 2)

                if let classificationSummary {
                    Text(classificationSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if shouldShowDateLabel {
                    dateLabel
                }

                metadataWrap
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            trailingChevron
                .padding(.top, 6)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Stacked Layout (Header row, then categories, then stats row)
    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: icon, type, chevron
            HStack(spacing: 12) {
                iconView(size: 44, iconSize: 20, cornerRadius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    workoutTitle(font: .system(size: 17, weight: .semibold))

                    if let classificationSummary {
                        Text(classificationSummary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                trailingChevron
            }

            // Bottom row: stats
            HStack(spacing: 16) {
                statPill(icon: "clock", value: formattedDuration(workout.duration))

                if let distance = workout.distance, distance > 0 {
                    statPill(icon: "figure.run", value: String(format: "%.1f km", distance))
                }

                Spacer()
            }
        }
        .padding(16)
        .glassCard(prominence: .elevated)
    }

    // MARK: - Split Layout (Two columns)
    private var splitLayout: some View {
        HStack(spacing: 16) {
            // Left column: type and categories
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    iconView(size: 40, iconSize: 18, cornerRadius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        workoutTitle(font: .system(size: 17, weight: .semibold))

                        if let classificationSummary {
                            Text(classificationSummary)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }

            }

            Spacer(minLength: 12)

            // Right column: stats and date
            VStack(alignment: .trailing, spacing: 8) {
                Text(formattedDuration(workout.duration))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                if let distance = workout.distance, distance > 0 {
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(workout.primaryWorkoutTintColor)
                }

                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            trailingChevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(prominence: .elevated)
    }

    // MARK: - Leading Layout (Duration prominent on left)
    private var leadingLayout: some View {
        HStack(spacing: 14) {
            // Duration block
            VStack(spacing: 2) {
                Text(formattedDuration(workout.duration))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                if let distance = workout.distance, distance > 0 {
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(workout.primaryWorkoutTintColor)
                }
            }
            .frame(width: 60)

            Rectangle()
                .fill(workout.primaryWorkoutTintColor.opacity(0.3))
                .frame(width: 2)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: workout.primaryWorkoutSystemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(workout.primaryWorkoutTintColor)

                    VStack(alignment: .leading, spacing: 4) {
                        workoutTitle(font: .system(size: 16, weight: .semibold))

                        if let classificationSummary {
                            Text(classificationSummary)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }

                dateText
            }

            Spacer(minLength: 8)

            trailingChevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(prominence: .elevated)
    }

    // MARK: - Compact Layout (Single line focus, minimal)
    private var compactLayout: some View {
        HStack(spacing: 12) {
            iconView(size: 36, iconSize: 16, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 2) {
                workoutTitle(font: .system(size: 15, weight: .semibold))

                if let classificationSummary {
                    Text(classificationSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Text(formattedDuration(workout.duration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                if let distance = workout.distance, distance > 0 {
                    Text(String(format: "%.1f km", distance))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(workout.primaryWorkoutTintColor)
                }

                    Text(shortDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            trailingChevron
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(prominence: .elevated)
    }

    // MARK: - Shared Components
    private func workoutTitle(font: Font, lineLimit: Int = 1) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(workout.primaryWorkoutDisplayName)
                .font(font)
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var healthKitImportedIcon: some View {
        Image(systemName: "heart.text.square.fill")
            .accessibilityLabel("Imported from HealthKit")
    }

    private func iconView(size: CGFloat, iconSize: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(workout.primaryWorkoutTintColor.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: workout.primaryWorkoutSystemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(workout.primaryWorkoutTintColor)
                )

            if isImportedFromHealthKit {
                healthKitImportedIcon
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(3)
                    .background(.thinMaterial, in: Circle())
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    .offset(x: 4, y: -4)
            }
        }
    }

    @ViewBuilder
    private var trailingChevron: some View {
        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var dateText: some View {
        Text(formattedDate)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
    }

    private var metadataWrap: some View {
        HStack(spacing: 8) {
            statChip(icon: "clock", value: formattedDuration(workout.duration))
            if let distance = workout.distance, distance > 0 {
                statChip(icon: distanceIconName, value: String(format: "%.1f km", distance), tinted: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryNames: [String] {
        let names = (workout.categories ?? [])
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: names)) as? [String] ?? []
    }

    private var subcategoryNames: [String] {
        let names = (workout.subcategories ?? [])
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: names)) as? [String] ?? []
    }

    private var categorySummaryText: String {
        summarizedText(from: categoryNames, limit: 2)
    }

    private var subcategorySummaryText: String {
        summarizedText(from: subcategoryNames, limit: 3)
    }

    private var classificationSummary: String? {
        let parts = [categorySummaryText, subcategorySummaryText].filter { !$0.isEmpty }
        let summary = parts.joined(separator: " · ")
        return summary.isEmpty ? nil : summary
    }

    private var dateLabel: some View {
        Text(shortDate)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var distanceBadge: some View {
        if let distance = workout.distance, distance > 0 {
            Text(String(format: "%.1f km", distance))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(workout.primaryWorkoutTintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(workout.primaryWorkoutTintColor.opacity(0.10))
                )
        }
    }

    private var distanceIconName: String {
        switch workout.appleWorkoutActivityType {
        case .cycling, .handCycling:
            return "bicycle"
        case .swimming, .waterFitness, .waterPolo, .waterSports, .underwaterDiving:
            return "drop.fill"
        case .rowing:
            return "figure.rower"
        default:
            return "arrow.left.and.right"
        }
    }

    private var isImportedFromHealthKit: Bool {
        guard let hkUUID = workout.hkUUID else { return false }
        return !hkUUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func statChip(icon: String, value: String, tinted: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tinted ? workout.primaryWorkoutTintColor : .secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tinted ? workout.primaryWorkoutTintColor : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(
                    tinted
                        ? workout.primaryWorkoutTintColor.opacity(0.10)
                        : Color(.tertiarySystemBackground)
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    tinted ? workout.primaryWorkoutTintColor.opacity(0.18) : Color.primary.opacity(0.08),
                    lineWidth: 0.75
                )
        )
    }

    private func summarizedText(from names: [String], limit: Int) -> String {
        let visible = Array(names.prefix(limit))
        let overflow = max(names.count - visible.count, 0)
        var parts = visible
        if overflow > 0 {
            parts.append("+\(overflow)")
        }
        return parts.joined(separator: ", ")
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemBackground))
        )
    }

    // MARK: - Helpers
    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.startDate) {
            return "Today, \(workout.startDate.formatted(date: .omitted, time: .shortened))"
        } else if calendar.isDateInYesterday(workout.startDate) {
            return "Yesterday, \(workout.startDate.formatted(date: .omitted, time: .shortened))"
        }
        return workout.startDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var shortDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.startDate) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.startDate) {
            return "Yesterday"
        }
        return workout.startDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var shouldShowDateLabel: Bool {
        let calendar = Calendar.current
        return !calendar.isDateInToday(workout.startDate) && !calendar.isDateInYesterday(workout.startDate)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}


// MARK: - Preview
#Preview("Workout Row") {
    WorkoutRowPreview()
}

private struct WorkoutRowPreview: View {
    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
        let context = container.mainContext

        let longNameWorkout = Workout(
            type: .strength,
            startDate: .now.addingTimeInterval(-18000),
            duration: 4260,
            distance: nil,
            hkActivityTypeRaw: Int(HKWorkoutActivityType.traditionalStrengthTraining.rawValue)
        )
        longNameWorkout.hkUUID = UUID().uuidString
        context.insert(longNameWorkout)

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Traditional Strength Training")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    WorkoutRowView(workout: longNameWorkout)
                }
                .padding()
            }
            .navigationTitle("Workout Row")
        }
        .modelContainer(container)
    }
}
