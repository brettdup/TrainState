import SwiftUI
import SwiftData

struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 14) {
            // Icon with tinted background
            Image(systemName: workout.type.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(workout.type.tintColor)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(workout.type.tintColor.opacity(0.12))
                )

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Primary: Type and duration
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(workout.type.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(formattedDuration(workout.duration))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Categories
                if let categories = workout.categories, !categories.isEmpty {
                    Text(categories.map(\.name).joined(separator: " · "))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Subcategories
                if let subcategories = workout.subcategories, !subcategories.isEmpty {
                    Text(subcategories.map(\.name).joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // Date/time
                Text(formattedDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            // Stats badge (if has distance)
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

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.startDate) {
            return "Today, \(workout.startDate.formatted(date: .omitted, time: .shortened))"
        } else if calendar.isDateInYesterday(workout.startDate) {
            return "Yesterday, \(workout.startDate.formatted(date: .omitted, time: .shortened))"
        }
        return workout.startDate.formatted(date: .abbreviated, time: .shortened)
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

#Preview("Workout Row") {
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

    // 1 category, 1 subcategory
    let minimal = Workout(
        type: .strength,
        startDate: .now.addingTimeInterval(-432000),
        duration: 1800,
        distance: nil,
        categories: [push],
        subcategories: [benchPress]
    )
    context.insert(minimal)

    // 1 category, 3 subcategories
    let pushDay = Workout(
        type: .strength,
        startDate: .now.addingTimeInterval(-518400),
        duration: 3000,
        distance: nil,
        categories: [push],
        subcategories: [benchPress, shoulderPress, triceps]
    )
    context.insert(pushDay)

    // 2 categories, 4 subcategories
    let legDay = Workout(
        type: .strength,
        startDate: .now.addingTimeInterval(-604800),
        duration: 4500,
        distance: nil,
        categories: [legs, core],
        subcategories: [squats, deadlifts, lunges, planks]
    )
    context.insert(legDay)

    // 4 categories, 6 subcategories (full body)
    let fullBody = Workout(
        type: .strength,
        startDate: .now.addingTimeInterval(-691200),
        duration: 5400,
        distance: nil,
        categories: [push, pull, legs, core],
        subcategories: [benchPress, shoulderPress, rows, pullUps, squats, planks]
    )
    context.insert(fullBody)

    return ScrollView {
        VStack(spacing: 12) {
            // Strength with varying subcategory counts
            WorkoutRowView(workout: minimal)       // 1 cat, 1 subcat
            WorkoutRowView(workout: pushDay)       // 1 cat, 3 subcats
            WorkoutRowView(workout: strengthWorkout) // 2 cats, 2 subcats
            WorkoutRowView(workout: legDay)        // 2 cats, 4 subcats
            WorkoutRowView(workout: fullBody)      // 4 cats, 6 subcats

            // Other workout types
            WorkoutRowView(workout: runningWorkout)  // with distance
            WorkoutRowView(workout: cyclingWorkout)  // with longer distance
            WorkoutRowView(workout: yogaWorkout)     // no cats, no distance
            WorkoutRowView(workout: cardioWorkout)   // 1 cat only
        }
        .padding()
    }
    .modelContainer(container)
}
