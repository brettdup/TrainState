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
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    if historyPoints.isEmpty {
                        emptyStateCard
                    } else {
                        metricCard
                        chartCard
                        historyCard
                    }
                }
                .glassEffectContainer(spacing: 20)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let latestPoint {
                statRow(label: "Last Trained", value: latestPoint.date.formatted(date: .abbreviated, time: .omitted))
                statRow(label: "Sessions Logged", value: "\(historyPoints.count)")
                statRow(label: "Best Top Set", value: metricString(bestTopSet, suffix: "kg"))
                statRow(label: "Best Est. 1RM", value: metricString(bestEstimatedOneRepMax, suffix: "kg"))
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
            Text("Metric")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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
            Text("Progress")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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
            Text("History")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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

    private func metricString(_ value: Double, suffix: String) -> String {
        "\(ExerciseLogEntry.displayWeight(value)) \(suffix)"
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

#Preview {
    NavigationStack {
        ExerciseInsightsView(exerciseName: "Bench Press", subcategoryID: nil)
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self], inMemory: true)
}
