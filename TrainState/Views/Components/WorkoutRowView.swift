import SwiftUI
import SwiftData

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
        HStack(spacing: 14) {
            iconView(size: 48, iconSize: 22, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(workout.type.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(formattedDuration(workout.duration))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                categoriesText
                subcategoriesText
                dateText
            }

            Spacer(minLength: 8)

            distanceBadge
            chevron
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Stacked Layout (Header row, then categories, then stats row)
    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: icon, type, chevron
            HStack(spacing: 12) {
                iconView(size: 44, iconSize: 20, cornerRadius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.type.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                chevron
            }

            // Categories & subcategories
            if hasCategories || hasSubcategories {
                VStack(alignment: .leading, spacing: 4) {
                    categoriesText
                    subcategoriesText
                }
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
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Split Layout (Two columns)
    private var splitLayout: some View {
        HStack(spacing: 16) {
            // Left column: type and categories
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    iconView(size: 40, iconSize: 18, cornerRadius: 10)

                    Text(workout.type.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                if hasCategories || hasSubcategories {
                    VStack(alignment: .leading, spacing: 3) {
                        categoriesText
                        subcategoriesText
                    }
                    .padding(.leading, 50)
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
                        .foregroundStyle(workout.type.tintColor)
                }

                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            chevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24)
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
                        .foregroundStyle(workout.type.tintColor)
                }
            }
            .frame(width: 60)

            Rectangle()
                .fill(workout.type.tintColor.opacity(0.3))
                .frame(width: 2)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: workout.type.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(workout.type.tintColor)

                    Text(workout.type.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                categoriesText
                subcategoriesText
                dateText
            }

            Spacer(minLength: 8)

            chevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Compact Layout (Single line focus, minimal)
    private var compactLayout: some View {
        HStack(spacing: 12) {
            iconView(size: 36, iconSize: 16, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let categories = workout.categories, !categories.isEmpty {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(categories.map(\.name).joined(separator: ", "))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 12) {
                    Text(formattedDuration(workout.duration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let distance = workout.distance, distance > 0 {
                        Text(String(format: "%.1f km", distance))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(workout.type.tintColor)
                    }

                    Text(shortDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            chevron
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Shared Components
    private func iconView(size: CGFloat, iconSize: CGFloat, cornerRadius: CGFloat) -> some View {
        Image(systemName: workout.type.systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(workout.type.tintColor)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(workout.type.tintColor.opacity(0.12))
            )
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.quaternary)
    }

    @ViewBuilder
    private var categoriesText: some View {
        if let categories = workout.categories, !categories.isEmpty {
            Text(categories.map(\.name).joined(separator: " · "))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var subcategoriesText: some View {
        if let subcategories = workout.subcategories, !subcategories.isEmpty {
            Text(subcategories.map(\.name).joined(separator: ", "))
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var dateText: some View {
        Text(formattedDate)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var distanceBadge: some View {
        if let distance = workout.distance, distance > 0 {
            Text(String(format: "%.1f km", distance))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(workout.type.tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(workout.type.tintColor.opacity(0.12))
                )
        }
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

    private var hasCategories: Bool {
        workout.categories?.isEmpty == false
    }

    private var hasSubcategories: Bool {
        workout.subcategories?.isEmpty == false
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
#Preview("Workout Row Layouts") {
    WorkoutRowPreview()
}

private struct WorkoutRowPreview: View {
    @State private var selectedStyle: WorkoutRowStyle = .standard

    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
        let context = container.mainContext

        let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
        let pull = WorkoutCategory(name: "Pull", color: "#4ECDC4", workoutType: .strength)
        let legs = WorkoutCategory(name: "Legs", color: "#45B7D1", workoutType: .strength)
        let core = WorkoutCategory(name: "Core", color: "#96CEB4", workoutType: .strength)
        context.insert(push)
        context.insert(pull)
        context.insert(legs)
        context.insert(core)

        let benchPress = WorkoutSubcategory(name: "Bench Press", category: push)
        let shoulderPress = WorkoutSubcategory(name: "Shoulder Press", category: push)
        let triceps = WorkoutSubcategory(name: "Triceps", category: push)
        let rows = WorkoutSubcategory(name: "Rows", category: pull)
        let pullUps = WorkoutSubcategory(name: "Pull Ups", category: pull)
        let biceps = WorkoutSubcategory(name: "Biceps", category: pull)
        let squats = WorkoutSubcategory(name: "Squats", category: legs)
        let deadlifts = WorkoutSubcategory(name: "Deadlifts", category: legs)
        let lunges = WorkoutSubcategory(name: "Lunges", category: legs)
        let planks = WorkoutSubcategory(name: "Planks", category: core)
        context.insert(benchPress)
        context.insert(shoulderPress)
        context.insert(triceps)
        context.insert(rows)
        context.insert(pullUps)
        context.insert(biceps)
        context.insert(squats)
        context.insert(deadlifts)
        context.insert(lunges)
        context.insert(planks)

        let strengthWorkout = Workout(
            type: .strength,
            startDate: .now,
            duration: 3600,
            distance: nil,
            categories: [push, pull],
            subcategories: [benchPress, rows]
        )
        context.insert(strengthWorkout)

        let runningWorkout = Workout(
            type: .running,
            startDate: .now.addingTimeInterval(-86400),
            duration: 2700,
            distance: 6.2
        )
        context.insert(runningWorkout)

        let yogaWorkout = Workout(
            type: .yoga,
            startDate: .now.addingTimeInterval(-172800),
            duration: 1800,
            distance: nil
        )
        context.insert(yogaWorkout)

        let cyclingWorkout = Workout(
            type: .cycling,
            startDate: .now.addingTimeInterval(-259200),
            duration: 5400,
            distance: 32.5
        )
        context.insert(cyclingWorkout)

        let cardioWorkout = Workout(
            type: .cardio,
            startDate: .now.addingTimeInterval(-345600),
            duration: 2400,
            distance: nil,
            categories: [push]
        )
        context.insert(cardioWorkout)

        let minimal = Workout(
            type: .strength,
            startDate: .now.addingTimeInterval(-432000),
            duration: 1800,
            distance: nil,
            categories: [push],
            subcategories: [benchPress]
        )
        context.insert(minimal)

        let pushDay = Workout(
            type: .strength,
            startDate: .now.addingTimeInterval(-518400),
            duration: 3000,
            distance: nil,
            categories: [push],
            subcategories: [benchPress, shoulderPress, triceps]
        )
        context.insert(pushDay)

        let legDay = Workout(
            type: .strength,
            startDate: .now.addingTimeInterval(-604800),
            duration: 4500,
            distance: nil,
            categories: [legs, core],
            subcategories: [squats, deadlifts, lunges, planks]
        )
        context.insert(legDay)

        let fullBody = Workout(
            type: .strength,
            startDate: .now.addingTimeInterval(-691200),
            duration: 5400,
            distance: nil,
            categories: [push, pull, legs, core],
            subcategories: [benchPress, shoulderPress, rows, pullUps, squats, planks]
        )
        context.insert(fullBody)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    WorkoutRowView(workout: minimal, style: selectedStyle)
                    WorkoutRowView(workout: pushDay, style: selectedStyle)
                    WorkoutRowView(workout: strengthWorkout, style: selectedStyle)
                    WorkoutRowView(workout: legDay, style: selectedStyle)
                    WorkoutRowView(workout: fullBody, style: selectedStyle)
                    WorkoutRowView(workout: runningWorkout, style: selectedStyle)
                    WorkoutRowView(workout: cyclingWorkout, style: selectedStyle)
                    WorkoutRowView(workout: yogaWorkout, style: selectedStyle)
                    WorkoutRowView(workout: cardioWorkout, style: selectedStyle)
                }
                .padding()
            }
            .navigationTitle("Workout Rows")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(WorkoutRowStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .modelContainer(container)
    }
}
