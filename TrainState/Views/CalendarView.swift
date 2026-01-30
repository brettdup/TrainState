import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @State private var selectedWeekStart: Date = Calendar.current.startOfWeek(for: Date())

    var body: some View {
        NavigationStack {
            List {
                weekHeader
                ForEach(weekDays, id: \.self) { day in
                    Section {
                        let dayWorkouts = workoutsForDay(day)
                        if dayWorkouts.isEmpty {
                            Text("No workouts")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dayWorkouts, id: \.id) { workout in
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
                        }
                    } header: {
                        Text(sectionHeaderTitle(for: day))
                            .textCase(nil)
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var weekHeader: some View {
        let rangeText = weekRangeText(for: selectedWeekStart)
        return HStack {
            Button {
                selectedWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: selectedWeekStart) ?? selectedWeekStart
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(rangeText)
                .font(.headline)
            Spacer()
            Button {
                let next = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart) ?? selectedWeekStart
                if next <= Calendar.current.startOfWeek(for: Date()) {
                    selectedWeekStart = next
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedWeekStart >= Calendar.current.startOfWeek(for: Date()))
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedWeekStart) }
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

    private func workoutsForDay(_ day: Date) -> [Workout] {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return workouts.filter { $0.startDate >= start && $0.startDate < end }
    }

    private func weekRangeText(for start: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        let year = Calendar.current.component(.year, from: end)
        return "\(startText) – \(endText), \(year)"
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let context = container.mainContext
    let calendar = Calendar.current
    func addWorkout(type: WorkoutType, daysAgo: Int, minutes: Double) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        context.insert(Workout(type: type, startDate: date, duration: minutes * 60))
    }
    addWorkout(type: .strength, daysAgo: 0, minutes: 45)
    addWorkout(type: .running, daysAgo: 1, minutes: 30)
    addWorkout(type: .yoga, daysAgo: 3, minutes: 25)
    return CalendarView()
        .modelContainer(container)
}
