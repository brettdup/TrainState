import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            List {
                Section("This Week") {
                    Text("Workouts: \(weeklySummary.count)")
                    Text("Duration: \(weeklySummary.duration)")
                    if weeklySummary.distance > 0 {
                        Text("Distance: \(weeklySummary.distance, format: .number.precision(.fractionLength(1))) km")
                    }
                }

                Section("All Time") {
                    Text("Workouts: \(allTimeSummary.count)")
                    Text("Duration: \(allTimeSummary.duration)")
                    if allTimeSummary.distance > 0 {
                        Text("Distance: \(allTimeSummary.distance, format: .number.precision(.fractionLength(1))) km")
                    }
                }
            }
            .navigationTitle("Analytics")
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
    AnalyticsView()
        .modelContainer(for: [Workout.self], inMemory: true)
}
