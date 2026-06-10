import Charts
import SwiftData
import SwiftUI

struct ExerciseInsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .forward) private var workouts: [Workout]

    let exerciseName: String
    let subcategoryID: UUID?

    @State private var selectedMetric: ExerciseInsightMetric = .topSet

    private var normalizedExerciseName: String {
        exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var historyPoints: [ExerciseHistoryPoint] {
        workouts.compactMap { workout in
            let matchingExercises = (workout.exercises ?? []).filter { exercise in
                let sameName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedExerciseName
                let sameSubcategory = subcategoryID == nil || exercise.subcategory?.id == subcategoryID
                return sameName && sameSubcategory
            }
            guard !matchingExercises.isEmpty else { return nil }

            let topSet = matchingExercises.compactMap(\.weight).max() ?? 0
            let estimated1RM = matchingExercises.compactMap { exercise -> Double? in
                guard let weight = exercise.weight, weight > 0 else { return nil }
                let reps = max(exercise.reps ?? 1, 1)
                return weight * (1 + Double(reps) / 30.0)
            }.max() ?? 0
            let volume = matchingExercises.reduce(0.0) { partial, exercise in
                let sets = Double(max(exercise.sets ?? 1, 1))
                let reps = Double(max(exercise.reps ?? 0, 0))
                let weight = max(exercise.weight ?? 0, 0)
                return partial + (sets * reps * weight)
            }

            return ExerciseHistoryPoint(
                id: workout.id,
                date: workout.startDate,
                topSetWeight: topSet,
                estimatedOneRepMax: estimated1RM,
                volume: volume
            )
        }
    }

    private var loggedEntries: [LoggedExerciseEntry] {
        workouts.flatMap { workout in
            (workout.exercises ?? []).compactMap { exercise in
                let sameName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedExerciseName
                let sameSubcategory = subcategoryID == nil || exercise.subcategory?.id == subcategoryID
                guard sameName && sameSubcategory else { return nil }

                return LoggedExerciseEntry(
                    workoutID: workout.id,
                    date: workout.startDate,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weight: exercise.weight,
                    notes: exercise.notes
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.date > rhs.date
        }
    }

    /// History points sorted in ascending date order to ensure charts and stats use a consistent timeline.
    private var sortedHistoryPoints: [ExerciseHistoryPoint] {
        historyPoints.sorted { $0.date < $1.date }
    }

    private var bestTopSet: Double {
        sortedHistoryPoints.map(\.topSetWeight).max() ?? 0
    }

    private var bestEstimatedOneRepMax: Double {
        sortedHistoryPoints.map(\.estimatedOneRepMax).max() ?? 0
    }

    private var latestPoint: ExerciseHistoryPoint? {
        sortedHistoryPoints.last
    }

    private var maxWeightEntry: LoggedExerciseEntry? {
        loggedEntries
            .filter { ($0.weight ?? 0) > 0 }
            .max { lhs, rhs in
                let lhsWeight = lhs.weight ?? 0
                let rhsWeight = rhs.weight ?? 0
                if lhsWeight == rhsWeight {
                    return (lhs.reps ?? 0) < (rhs.reps ?? 0)
                }
                return lhsWeight < rhsWeight
            }
    }

    private var maxRepsAtMaxWeight: Int? {
        guard let maxWeight = maxWeightEntry?.weight else { return nil }
        return loggedEntries
            .filter { ($0.weight ?? 0) == maxWeight }
            .compactMap(\.reps)
            .max()
    }

    private var trendDelta: Double {
        guard sortedHistoryPoints.count >= 2 else { return 0 }
        let latest = sortedHistoryPoints[sortedHistoryPoints.count - 1]
        let previous = sortedHistoryPoints[sortedHistoryPoints.count - 2]
        switch selectedMetric {
        case .topSet:
            return latest.topSetWeight - previous.topSetWeight
        case .estimatedOneRepMax:
            return latest.estimatedOneRepMax - previous.estimatedOneRepMax
        case .volume:
            return latest.volume - previous.volume
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.10),
                    ThemeColor.primaryUi02().opacity(colorScheme == .dark ? 0.35 : 0.65),
                    ThemeColor.primaryUi01()
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    if historyPoints.isEmpty {
                        emptyStateCard
                    } else {
                        metricCard
                        chartCard
                        historyCard
                        individualEntriesCard
                    }
                }
                .glassEffectContainer(spacing: 16)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            exerciseInsightsHeader(
                title: "Overview",
                subtitle: latestPoint.map { "Last trained \($0.date.formatted(date: .abbreviated, time: .omitted))" } ?? "No logged data yet",
                icon: "dumbbell.fill"
            )

            if let latestPoint {
                HStack(spacing: 12) {
                    insightMetricTile(title: "Sessions", value: "\(historyPoints.count)", icon: "calendar")
                    insightMetricTile(title: "Entries", value: "\(loggedEntries.count)", icon: "list.bullet")
                    insightMetricTile(title: "Top Set", value: metricString(bestTopSet, suffix: "kg"), icon: "trophy")
                }

                statRow(label: "Last Trained", value: latestPoint.date.formatted(date: .abbreviated, time: .omitted))
                statRow(label: "Best Est. 1RM", value: metricString(bestEstimatedOneRepMax, suffix: "kg"))
                statRow(label: "Max Reps @ Max Weight", value: maxRepsAtMaxWeightSummary)
            } else {
                Text("No logged data for this exercise yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .glassCard()
    }

    private var metricCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            exerciseInsightsHeader(title: "Metric", subtitle: "Choose the progression line to inspect.", icon: "slider.horizontal.3")

            Picker("Metric", selection: $selectedMetric) {
                ForEach(ExerciseInsightMetric.allCases, id: \.self) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if sortedHistoryPoints.count > 1 {
                let sign = trendDelta >= 0 ? "+" : ""
                Text("Last session change: \(sign)\(metricString(abs(trendDelta), suffix: selectedMetric.suffix))")
                    .font(.caption)
                    .foregroundStyle(trendDelta >= 0 ? Color.green : Color.orange)
            }
        }
        .padding(20)
        .glassCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            exerciseInsightsHeader(title: "Progress", subtitle: selectedMetric.title, icon: "chart.xyaxis.line")

            Chart(sortedHistoryPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.title, point.value(for: selectedMetric))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.title, point.value(for: selectedMetric))
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(20)
        .glassCard()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            exerciseInsightsHeader(title: "History", subtitle: "\(sortedHistoryPoints.count) session\(sortedHistoryPoints.count == 1 ? "" : "s")", icon: "clock.arrow.circlepath")

            ForEach(sortedHistoryPoints.reversed()) { point in
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    Text(
                        "Top Set \(metricString(point.topSetWeight, suffix: "kg")) • Est. 1RM \(metricString(point.estimatedOneRepMax, suffix: "kg")) • Volume \(metricString(point.volume, suffix: "kg"))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .glassCard()
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Exercise History")
                .font(.subheadline.weight(.semibold))
            Text("Log this exercise in more workouts to unlock PB trends and progression charts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var individualEntriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            exerciseInsightsHeader(title: "Individual Entries", subtitle: "\(loggedEntries.count) logged set entr\(loggedEntries.count == 1 ? "y" : "ies")", icon: "list.bullet.rectangle")

            ForEach(loggedEntries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))

                    Text(entry.entrySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let notes = entry.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .glassCard()
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func exerciseInsightsHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func insightMetricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .monospacedDigit()
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColor.primaryUi03())
        )
    }

    private func metricString(_ value: Double, suffix: String) -> String {
        "\(ExerciseLogEntry.displayWeight(value)) \(suffix)"
    }

    private var maxRepsAtMaxWeightSummary: String {
        guard
            let maxWeight = maxWeightEntry?.weight,
            let maxRepsAtMaxWeight
        else {
            return "N/A"
        }

        return "\(maxRepsAtMaxWeight) reps @ \(ExerciseLogEntry.displayWeight(maxWeight)) kg"
    }
}

private struct ExerciseHistoryPoint: Identifiable {
    let id: UUID
    let date: Date
    let topSetWeight: Double
    let estimatedOneRepMax: Double
    let volume: Double

    func value(for metric: ExerciseInsightMetric) -> Double {
        switch metric {
        case .topSet:
            return topSetWeight
        case .estimatedOneRepMax:
            return estimatedOneRepMax
        case .volume:
            return volume
        }
    }
}

private enum ExerciseInsightMetric: CaseIterable {
    case topSet
    case estimatedOneRepMax
    case volume

    var title: String {
        switch self {
        case .topSet:
            return "Top Set"
        case .estimatedOneRepMax:
            return "Est. 1RM"
        case .volume:
            return "Volume"
        }
    }

    var suffix: String {
        "kg"
    }
}

private struct LoggedExerciseEntry: Identifiable {
    let id = UUID()
    let workoutID: UUID
    let date: Date
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let notes: String?

    var entrySummary: String {
        var parts: [String] = []

        if let sets, sets > 0 {
            parts.append("\(sets) sets")
        }

        if let reps, reps > 0 {
            parts.append("\(reps) reps")
        }

        if let weight, weight > 0 {
            parts.append("\(ExerciseLogEntry.displayWeight(weight)) kg")
        }

        return parts.isEmpty ? "Logged entry" : parts.joined(separator: " • ")
    }
}

#Preview {
    NavigationStack {
        ExerciseInsightsView(exerciseName: "Bench Press", subcategoryID: nil)
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, WorkoutExercise.self], inMemory: true)
}
