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
                Text(workout.primaryWorkoutDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if hasCategorySummary {
                    categorySummaryView
                }

                if hasSubcategorySummary {
                    subcategorySummaryView
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
                    Text(workout.primaryWorkoutDisplayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    if hasCategorySummary {
                        categorySummaryView
                    }

                    if hasSubcategorySummary {
                        subcategorySummaryView
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
                        Text(workout.primaryWorkoutDisplayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        if hasCategorySummary {
                            categorySummaryView
                        }

                        if hasSubcategorySummary {
                            subcategorySummaryView
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
                        Text(workout.primaryWorkoutDisplayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        if hasCategorySummary {
                            categorySummaryView
                        }

                        if hasSubcategorySummary {
                            subcategorySummaryView
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(workout.primaryWorkoutDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                }

                if hasCategorySummary {
                    categorySummaryView
                }

                if hasSubcategorySummary {
                    subcategorySummaryView
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
    private func iconView(size: CGFloat, iconSize: CGFloat, cornerRadius: CGFloat) -> some View {
        Image(systemName: workout.primaryWorkoutSystemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(workout.primaryWorkoutTintColor)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(workout.primaryWorkoutTintColor.opacity(0.12))
            )
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

    private var hasCategorySummary: Bool {
        !categorySummary.isEmpty
    }

    private var hasSubcategorySummary: Bool {
        !subcategorySummary.isEmpty
    }

    private var categorySummary: String {
        let categoryNames = (workout.categories ?? [])
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let ordered = Array(NSOrderedSet(array: categoryNames)) as? [String] ?? []
        return ordered.prefix(2).joined(separator: " • ")
    }

    private var subcategorySummary: String {
        let subcategoryNames = (workout.subcategories ?? [])
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let ordered = Array(NSOrderedSet(array: subcategoryNames)) as? [String] ?? []
        return ordered.prefix(3).joined(separator: " • ")
    }

    private var categorySummaryView: some View {
        Label {
            Text(categorySummary)
        } icon: {
            Image(systemName: "folder")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var subcategorySummaryView: some View {
        Label {
            Text(subcategorySummary)
        } icon: {
            Image(systemName: "tag")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(2)
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
