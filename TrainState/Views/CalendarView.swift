import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            List {
                if groupedWorkouts.isEmpty {
                    Text("No workouts yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groupedWorkouts, id: \.date) { entry in
                        Section {
                            ForEach(entry.items, id: \.id) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
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
                        } header: {
                            Text(sectionHeaderTitle(for: entry.date))
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
        }
    }

    private var groupedWorkouts: [(date: Date, items: [Workout])] {
        let grouped = Dictionary(grouping: workouts) { Calendar.current.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    private func sectionHeaderTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let context = container.mainContext
    let workout = Workout(type: .strength, startDate: .now, duration: 1800)
    context.insert(workout)
    return CalendarView()
        .modelContainer(container)
}
