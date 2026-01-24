import SwiftUI
import SwiftData

struct WeeklyView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    var body: some View {
        List {
            ForEach(thisWeekWorkouts, id: \.id) { workout in
                HStack {
                    Image(systemName: workout.type.systemImage)
                        .foregroundStyle(workout.type.tintColor)
                    Text(workout.type.rawValue)
                    Spacer()
                    Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("This Week")
    }

    private var thisWeekWorkouts: [Workout] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return workouts.filter { weekInterval.contains($0.startDate) }
    }
}

#Preview {
    NavigationStack {
        WeeklyView()
    }
    .modelContainer(for: [Workout.self], inMemory: true)
}
