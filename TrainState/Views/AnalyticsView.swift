import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

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
                    summaryCard(title: "This Week", summary: weeklySummary)
                    summaryCard(title: "All Time", summary: allTimeSummary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        }
    }

    private func summaryCard(title: String, summary: (count: Int, duration: String, distance: Double)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                statRow(label: "Workouts", value: "\(summary.count)")
                statRow(label: "Duration", value: summary.duration)
                if summary.distance > 0 {
                    statRow(label: "Distance", value: String(format: "%.1f km", summary.distance))
                }
            }
            .padding(20)
            .glassCard(cornerRadius: 32)
        }
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

    private var weeklySummary: (count: Int, duration: String, distance: Double) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return (0, formattedDuration(0), 0)
        }
        let weekWorkouts = workouts.filter { weekInterval.contains($0.startDate) }
        let duration = weekWorkouts.reduce(0) { $0 + $1.duration }
        let distance = weekWorkouts.reduce(0) { $0 + ($1.distance ?? 0) }
        return (weekWorkouts.count, formattedDuration(duration), distance)
    }

    private var allTimeSummary: (count: Int, duration: String, distance: Double) {
        let duration = workouts.reduce(0) { $0 + $1.duration }
        let distance = workouts.reduce(0) { $0 + ($1.distance ?? 0) }
        return (workouts.count, formattedDuration(duration), distance)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
    .modelContainer(for: [Workout.self], inMemory: true)
}
