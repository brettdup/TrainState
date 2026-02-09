import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @AppStorage("weeklyGoalWorkouts") private var weeklyGoalWorkouts: Int = 4
    @AppStorage("weeklyGoalMinutes") private var weeklyGoalMinutes: Int = 180

    @State private var selectedFilter: AnalyticsWorkoutFilter = .all
    @State private var showAllPersonalBests = false

    var body: some View {
        NavigationStack {
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

                ScrollView {
                    LazyVStack(spacing: 16) {
                        filterCard
                        NavigationLink {
                            SubcategoryLastLoggedView()
                        } label: {
                            strengthInventoryCard
                        }
                        .buttonStyle(.plain)
                        weeklyGoalsCard
                        streakCard
                        personalBestsCard
                        smartPROpportunitiesCard
                        adaptivePlanCard
                        untrainedCategoriesCard
                        summaryCard(title: "All Time", summary: allTimeSummary)
                    }
                    .glassEffectContainer(spacing: 16)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Filter")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Workout Filter", selection: $selectedFilter) {
                ForEach(AnalyticsWorkoutFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var weeklyGoalsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Goals")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                statRow(label: "Workouts", value: "\(weeklySummary.count)/\(weeklyGoalWorkouts)")
                ProgressView(value: workoutGoalProgress)
                statRow(label: "Minutes", value: "\(weeklyMinutes)/\(weeklyGoalMinutes)")
                ProgressView(value: minuteGoalProgress)
            }

            Divider().opacity(0.2)

            VStack(spacing: 12) {
                Stepper("Workout Goal: \(weeklyGoalWorkouts)", value: $weeklyGoalWorkouts, in: 1...14)
                Stepper("Minutes Goal: \(weeklyGoalMinutes)", value: $weeklyGoalMinutes, in: 30...1000, step: 15)
            }
            .font(.subheadline)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var strengthInventoryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Strength Last Trained List")
                    .font(.subheadline.weight(.semibold))
                Text("Full list of strength subcategories and exercises with last-trained dates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streaks")
                .font(.headline)
                .foregroundStyle(.secondary)

            statRow(label: "Current Daily Streak", value: "\(currentDailyStreak) days")
            statRow(label: "Best Daily Streak", value: "\(bestDailyStreak) days")
            statRow(label: "Weekly Goal Streak", value: "\(weeklyGoalStreak) weeks")
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Personal Bests")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if exercisePRs.count > 5 {
                    Button(showAllPersonalBests ? "Show Top 5" : "View All") {
                        showAllPersonalBests.toggle()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                }
            }

            if exercisePRs.isEmpty {
                Text("Log weighted lifts (for example Bench Press) to track personal bests.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visiblePersonalBests, id: \.exerciseName) { pr in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pr.exerciseName)
                            .font(.subheadline.weight(.semibold))
                        Text(
                            String(
                                format: "Top Set: %.1f kg  •  Est 1RM: %.1f kg  •  %@",
                                pr.topSetWeight,
                                pr.estimatedOneRepMax,
                                pr.date.formatted(date: .abbreviated, time: .omitted)
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var smartPROpportunitiesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart PR Opportunities")
                .font(.headline)
                .foregroundStyle(.secondary)

            if smartPROpportunities.isEmpty {
                Text("No near-PR lifts right now. Keep logging sets and we’ll surface opportunities.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(smartPROpportunities.prefix(3), id: \.exerciseName) { opportunity in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opportunity.exerciseName)
                            .font(.subheadline.weight(.semibold))
                        Text(String(format: "You’re at %.0f%% of your PR. Latest %.1f kg vs PR %.1f kg.", opportunity.progressToPR * 100, opportunity.latestTopSet, opportunity.prTopSet))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var adaptivePlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adaptive Plan")
                .font(.headline)
                .foregroundStyle(.secondary)

            if adaptiveRecommendations.isEmpty {
                Text("No clear gaps yet. Log a few more workouts for tailored recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(adaptiveRecommendations, id: \.name) { rec in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rec.name)
                                .font(.subheadline.weight(.semibold))
                            Text(rec.reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var untrainedCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Not Trained Yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            if untrainedCategories.isEmpty {
                Text("Every available category for this filter has training history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(untrainedCategories, id: \.id) { category in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: category.color) ?? .secondary)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(category.workoutType?.rawValue ?? "General")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private func summaryCard(title: String, summary: (count: Int, duration: String, distance: Double)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            statRow(label: "Workouts", value: "\(summary.count)")
            statRow(label: "Duration", value: summary.duration)
            if summary.distance > 0 {
                statRow(label: "Distance", value: String(format: "%.1f km", summary.distance))
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private var filteredWorkouts: [Workout] {
        switch selectedFilter {
        case .all:
            return workouts
        case .strength:
            return workouts.filter { $0.type == .strength }
        }
    }

    private var filteredSubcategories: [WorkoutSubcategory] {
        switch selectedFilter {
        case .all:
            return subcategories
        case .strength:
            return subcategories.filter { $0.category?.workoutType == .strength }
        }
    }

    private var categoriesForFilter: [WorkoutCategory] {
        switch selectedFilter {
        case .all:
            return categories
        case .strength:
            return categories.filter { $0.workoutType == .strength }
        }
    }

    private var untrainedCategories: [WorkoutCategory] {
        let trainedCategoryIDs: Set<UUID> = Set(filteredWorkouts.flatMap { workout in
            var ids = workout.categories?.map(\.id) ?? []
            ids.append(contentsOf: (workout.subcategories ?? []).compactMap { $0.category?.id })
            return ids
        })

        return categoriesForFilter
            .filter { !trainedCategoryIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var weeklySummary: (count: Int, duration: String, distance: Double) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return (0, formattedDuration(0), 0)
        }
        let weekWorkouts = filteredWorkouts.filter { weekInterval.contains($0.startDate) }
        let duration = weekWorkouts.reduce(0) { $0 + $1.duration }
        let distance = weekWorkouts.reduce(0) { $0 + ($1.distance ?? 0) }
        return (weekWorkouts.count, formattedDuration(duration), distance)
    }

    private var allTimeSummary: (count: Int, duration: String, distance: Double) {
        let duration = filteredWorkouts.reduce(0) { $0 + $1.duration }
        let distance = filteredWorkouts.reduce(0) { $0 + ($1.distance ?? 0) }
        return (filteredWorkouts.count, formattedDuration(duration), distance)
    }

    private var weeklyMinutes: Int {
        Int(workoutsThisWeek.reduce(0) { $0 + $1.duration } / 60.0)
    }

    private var workoutsThisWeek: [Workout] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return filteredWorkouts.filter { weekInterval.contains($0.startDate) }
    }

    private var workoutGoalProgress: Double {
        min(Double(workoutsThisWeek.count) / Double(max(weeklyGoalWorkouts, 1)), 1)
    }

    private var minuteGoalProgress: Double {
        min(Double(weeklyMinutes) / Double(max(weeklyGoalMinutes, 1)), 1)
    }

    private var currentDailyStreak: Int {
        let calendar = Calendar.current
        let days = Set(filteredWorkouts.map { calendar.startOfDay(for: $0.startDate) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) {
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private var bestDailyStreak: Int {
        let calendar = Calendar.current
        let sortedDays = Set(filteredWorkouts.map { calendar.startOfDay(for: $0.startDate) }).sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for index in 1..<sortedDays.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: sortedDays[index - 1]),
               calendar.isDate(sortedDays[index], inSameDayAs: expected) {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }

    private var weeklyGoalStreak: Int {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        var streak = 0
        var cursor = thisWeekStart

        while true {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            let count = filteredWorkouts.filter { $0.startDate >= cursor && $0.startDate < nextWeek }.count
            if count >= weeklyGoalWorkouts {
                streak += 1
            } else {
                break
            }
            guard let previousWeek = calendar.date(byAdding: .day, value: -7, to: cursor) else { break }
            cursor = previousWeek
        }
        return streak
    }

    private var exercisePRs: [ExercisePR] {
        var bestByExercise: [String: ExercisePR] = [:]

        for workout in filteredWorkouts {
            for exercise in workout.exercises ?? [] {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let weight = exercise.weight, weight > 0 else { continue }
                let reps = max(exercise.reps ?? 1, 1)
                let estimatedOneRepMax = weight * (1 + Double(reps) / 30.0)

                let current = bestByExercise[name]
                if current == nil || estimatedOneRepMax > current!.estimatedOneRepMax {
                    bestByExercise[name] = ExercisePR(
                        exerciseName: name,
                        topSetWeight: weight,
                        estimatedOneRepMax: estimatedOneRepMax,
                        date: workout.startDate
                    )
                }
            }
        }

        return bestByExercise.values.sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
    }

    private var visiblePersonalBests: [ExercisePR] {
        showAllPersonalBests ? exercisePRs : Array(exercisePRs.prefix(5))
    }

    private var smartPROpportunities: [SmartPROpportunity] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let prs = Dictionary(uniqueKeysWithValues: exercisePRs.map { ($0.exerciseName, $0) })
        var recentBest: [String: Double] = [:]

        for workout in filteredWorkouts where workout.startDate >= twoWeeksAgo {
            for exercise in workout.exercises ?? [] {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let weight = exercise.weight, weight > 0 else { continue }
                recentBest[name] = max(recentBest[name] ?? 0, weight)
            }
        }

        return recentBest.compactMap { name, latest in
            guard let pr = prs[name], pr.topSetWeight > 0 else { return nil }
            let progress = latest / pr.topSetWeight
            guard progress >= 0.9 && progress < 1 else { return nil }
            return SmartPROpportunity(
                exerciseName: name,
                latestTopSet: latest,
                prTopSet: pr.topSetWeight,
                progressToPR: progress
            )
        }
        .sorted { $0.progressToPR > $1.progressToPR }
    }

    private var adaptiveRecommendations: [AdaptiveRecommendation] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let recentWorkouts = filteredWorkouts.filter { $0.startDate >= twoWeeksAgo }

        let counts: [UUID: Int] = filteredSubcategories.reduce(into: [:]) { result, subcategory in
            let count = recentWorkouts.reduce(0) { partial, workout in
                let hasSubcategory = (workout.subcategories ?? []).contains { $0.id == subcategory.id }
                return partial + (hasSubcategory ? 1 : 0)
            }
            result[subcategory.id] = count
        }

        return filteredSubcategories
            .sorted { (counts[$0.id] ?? 0) < (counts[$1.id] ?? 0) }
            .prefix(3)
            .map { subcategory in
                let hits = counts[subcategory.id] ?? 0
                let reason = hits == 0
                    ? "No sessions in the last 14 days. Add this to your next workout."
                    : "Only \(hits) session\(hits == 1 ? "" : "s") in the last 14 days. Consider increasing frequency."
                return AdaptiveRecommendation(name: subcategory.name, reason: reason)
            }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }
}

private enum AnalyticsWorkoutFilter: String, CaseIterable, Identifiable {
    case all
    case strength

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .strength: return "Strength"
        }
    }
}

private struct ExercisePR {
    let exerciseName: String
    let topSetWeight: Double
    let estimatedOneRepMax: Double
    let date: Date
}

private struct SmartPROpportunity {
    let exerciseName: String
    let latestTopSet: Double
    let prTopSet: Double
    let progressToPR: Double
}

private struct AdaptiveRecommendation {
    let name: String
    let reason: String
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self], inMemory: true)
}
