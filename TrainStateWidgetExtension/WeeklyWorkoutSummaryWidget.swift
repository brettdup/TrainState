import WidgetKit
import SwiftUI
import Foundation

private let appGroupIdentifier = "group.brettduplessis.TrainState"
private let snapshotKey = "weeklyWorkoutWidgetSnapshot"
private let widgetKind = "WeeklyWorkoutSummaryWidget"

struct WeeklyWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WeeklyWorkoutSnapshot
}

struct WeeklyWorkoutSnapshot: Codable {
    let workoutsThisWeek: Int
    let weeklyMinutes: Int
    let weeklyCalories: Int?
    let weeklyDistanceKilometers: Double?
    let trainedDaysThisWeek: Int
    let currentStreak: Int
    let lastWorkoutTitle: String
    let typeBreakdown: [WeeklyWorkoutTypeSummary]?
    let updatedAt: Date

    static let placeholder = WeeklyWorkoutSnapshot(
        workoutsThisWeek: 4,
        weeklyMinutes: 235,
        weeklyCalories: 1840,
        weeklyDistanceKilometers: 12.4,
        trainedDaysThisWeek: 3,
        currentStreak: 8,
        lastWorkoutTitle: "Strength Training",
        typeBreakdown: [
            WeeklyWorkoutTypeSummary(title: "Strength Training", systemImage: "dumbbell.fill", count: 2),
            WeeklyWorkoutTypeSummary(title: "Running", systemImage: "figure.run", count: 1),
            WeeklyWorkoutTypeSummary(title: "Cycling", systemImage: "bicycle", count: 1)
        ],
        updatedAt: .now
    )

    static let empty = WeeklyWorkoutSnapshot(
        workoutsThisWeek: 0,
        weeklyMinutes: 0,
        weeklyCalories: 0,
        weeklyDistanceKilometers: 0,
        trainedDaysThisWeek: 0,
        currentStreak: 0,
        lastWorkoutTitle: "No workouts yet",
        typeBreakdown: [],
        updatedAt: .now
    )
}

struct WeeklyWorkoutTypeSummary: Codable, Hashable {
    let title: String
    let systemImage: String
    let count: Int
}

struct WeeklyWorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyWorkoutEntry {
        WeeklyWorkoutEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyWorkoutEntry) -> Void) {
        completion(WeeklyWorkoutEntry(date: .now, snapshot: readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyWorkoutEntry>) -> Void) {
        let entry = WeeklyWorkoutEntry(date: .now, snapshot: readSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now.addingTimeInterval(7_200)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func readSnapshot() -> WeeklyWorkoutSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WeeklyWorkoutSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

struct WeeklyWorkoutSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: WeeklyWorkoutProvider()) { entry in
            WeeklyWorkoutWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Weekly Training")
        .description("See this week's workout count, training minutes, active days, distance, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct WeeklyWorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeeklyWorkoutEntry

    var body: some View {
        switch family {
        case .systemLarge:
            WeeklyWorkoutLargeView(snapshot: entry.snapshot)
        case .systemMedium:
            WeeklyWorkoutMediumView(snapshot: entry.snapshot)
        default:
            WeeklyWorkoutSmallView(snapshot: entry.snapshot)
        }
    }
}

private struct WeeklyWorkoutSmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: WeeklyWorkoutSnapshot
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.mint)
                Spacer()
                Text("WEEK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.workoutsThisWeek)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .contentTransition(.numericText())

                Text(snapshot.workoutsThisWeek == 1 ? "workout" : "workouts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                CompactMetricRow(systemImage: "clock.fill", value: "\(snapshot.weeklyMinutes) min")
                CompactMetricRow(systemImage: "flame.fill", value: "\(snapshot.currentStreak) day streak")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 46)
    }
}

private struct WeeklyWorkoutMediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: WeeklyWorkoutSnapshot
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: "bolt.heart.fill")
                        .foregroundStyle(.mint)
                    Text("This Week")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryText)
                }

                Text("\(snapshot.workoutsThisWeek)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .contentTransition(.numericText())

                Text(snapshot.workoutsThisWeek == 1 ? "workout logged" : "workouts logged")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)

                WorkoutTypeSummaryRow(items: snapshot.visibleTypeBreakdown, maxItems: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                WidgetMetricCard(title: "Minutes", value: "\(snapshot.weeklyMinutes)", systemImage: "clock.fill", color: .cyan)
                WidgetMetricCard(title: "Days", value: "\(snapshot.trainedDaysThisWeek)", systemImage: "calendar", color: .mint)
                WidgetMetricCard(title: "Streak", value: "\(snapshot.currentStreak)", systemImage: "flame.fill", color: .orange)
            }
            .frame(width: 112)
            .padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
}

private struct WeeklyWorkoutLargeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: WeeklyWorkoutSnapshot
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundStyle(.mint)
                        Text("This Week")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(snapshot.workoutsThisWeek)")
                            .font(.system(size: 58, weight: .heavy, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .contentTransition(.numericText())

                        Text(snapshot.workoutsThisWeek == 1 ? "workout" : "workouts")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(snapshot.currentStreak)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(palette.primaryText)
                    Text("day streak")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            WorkoutTypeSummaryRow(items: snapshot.visibleTypeBreakdown, maxItems: 5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                LargeWidgetMetricCard(title: "Minutes", value: "\(snapshot.weeklyMinutes)", systemImage: "clock.fill", color: .cyan)
                LargeWidgetMetricCard(title: "Distance", value: snapshot.distanceText, systemImage: "figure.run", color: .mint)
                LargeWidgetMetricCard(title: "Calories", value: snapshot.calorieText, systemImage: "flame.fill", color: .orange)
                LargeWidgetMetricCard(title: "Active Days", value: "\(snapshot.trainedDaysThisWeek)", systemImage: "calendar", color: .teal)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }
}

private struct CompactMetricRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let value: String
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .frame(width: 13)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(palette.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.70)
    }
}

private struct WidgetMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(palette.primaryText)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.tertiaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct LargeWidgetMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.tertiaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct WorkoutTypeSummaryRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [WeeklyWorkoutTypeSummary]
    let maxItems: Int
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(items.prefix(maxItems)), id: \.self) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.systemImage)
                    Text("\(item.count)")
                        .monospacedDigit()
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(palette.cardBackground, in: Capsule())
            }

            if items.isEmpty {
                Text("No workouts yet")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .lineLimit(1)
    }
}

struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: WidgetPalette(colorScheme: colorScheme).backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct WidgetPalette {
    let colorScheme: ColorScheme

    var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.08, blue: 0.09),
                Color(red: 0.10, green: 0.14, blue: 0.13)
            ]
        }
        return [
            Color(red: 0.95, green: 0.99, blue: 0.97),
            Color(red: 0.86, green: 0.94, blue: 0.91)
        ]
    }

    var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.07, green: 0.09, blue: 0.09)
    }

    var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.70) : Color(red: 0.18, green: 0.24, blue: 0.23).opacity(0.76)
    }

    var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.56) : Color(red: 0.24, green: 0.31, blue: 0.30).opacity(0.62)
    }

    var cardBackground: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(0.72)
    }
}

private extension WeeklyWorkoutSnapshot {
    var visibleTypeBreakdown: [WeeklyWorkoutTypeSummary] {
        typeBreakdown ?? []
    }

    var distanceText: String {
        let distance = weeklyDistanceKilometers ?? 0
        return distance > 0 ? String(format: "%.1f km", distance) : "0 km"
    }

    var calorieText: String {
        guard let weeklyCalories else { return "0" }
        if weeklyCalories >= 1_000 {
            return "\(weeklyCalories / 1_000)k"
        }
        return "\(weeklyCalories)"
    }
}

#Preview("Small", as: .systemSmall) {
    WeeklyWorkoutSummaryWidget()
} timeline: {
    WeeklyWorkoutEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    WeeklyWorkoutSummaryWidget()
} timeline: {
    WeeklyWorkoutEntry(date: .now, snapshot: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    WeeklyWorkoutSummaryWidget()
} timeline: {
    WeeklyWorkoutEntry(date: .now, snapshot: .placeholder)
}
