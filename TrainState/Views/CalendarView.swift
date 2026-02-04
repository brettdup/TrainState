import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @State private var selectedWeekStart: Date = Calendar.current.startOfWeek(for: Date())

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
                GlassEffectContainerWrapper(spacing: 16) {
                    LazyVStack(spacing: 16) {
                        weekNavigatorCard
                        weekSummaryCard
                        ForEach(weekDays, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sectionHeaderTitle(for: day))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            let dayWorkouts = workoutsForDay(day)
                            if dayWorkouts.isEmpty {
                                HStack {
                                    Image(systemName: "moon.zzz.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.tertiary)
                                    Text("Rest day")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(cornerRadius: 32)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(dayWorkouts, id: \.id) { workout in
                                        NavigationLink {
                                            WorkoutDetailView(workout: workout)
                                        } label: {
                                            CalendarWorkoutRow(workout: workout)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
        }
    }

    private var weekNavigatorCard: some View {
        HStack {
            Button {
                selectedWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: selectedWeekStart) ?? selectedWeekStart
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(weekRangeText(for: selectedWeekStart))
                .font(.headline)
            Spacer()
            Button {
                let next = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart) ?? selectedWeekStart
                if next <= Calendar.current.startOfWeek(for: Date()) {
                    selectedWeekStart = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(selectedWeekStart >= Calendar.current.startOfWeek(for: Date()))
            Button {
                selectedWeekStart = Calendar.current.startOfWeek(for: Date())
            } label: {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .opacity(isShowingCurrentWeek ? 0.5 : 1)
            .disabled(isShowingCurrentWeek)
        }
        .padding(16)
        .glassCard(cornerRadius: 32)
    }

    private var isShowingCurrentWeek: Bool {
        Calendar.current.isDate(selectedWeekStart, equalTo: Calendar.current.startOfWeek(for: Date()), toGranularity: .weekOfYear)
    }

    private var weekSummaryCard: some View {
        let summary = weekSummary(for: workoutsInDisplayedWeek)
        return HStack(spacing: 24) {
            SummaryStat(value: "\(summary.count)", label: "Workouts")
            Divider()
                .frame(height: 32)
            SummaryStat(value: summary.duration, label: "Duration")
            if summary.distance > 0 {
                Divider()
                    .frame(height: 32)
                SummaryStat(value: String(format: "%.1f km", summary.distance), label: "Distance")
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 32)
    }

    private var workoutsInDisplayedWeek: [Workout] {
        let start = selectedWeekStart
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return [] }
        return workouts.filter { $0.startDate >= start && $0.startDate < end }
    }

    private func weekSummary(for workouts: [Workout]) -> (count: Int, duration: String, distance: Double) {
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let totalDistance = workouts.compactMap(\.distance).reduce(0, +)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        let durationText = formatter.string(from: totalDuration) ?? "0m"
        return (workouts.count, durationText, totalDistance)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedWeekStart) }
    }

    private func sectionHeaderTitle(for date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let dayName = dayFormatter.string(from: date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateText = dateFormatter.string(from: date)

        if Calendar.current.isDateInToday(date) {
            return "Today · \(dayName)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday · \(dayName)"
        }
        return "\(dayName), \(dateText)"
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

// MARK: - Summary Stat
private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar Workout Row (with duration and distance)
private struct CalendarWorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: workout.type.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(workout.type.tintColor)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(workout.type.tintColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Group {
                if !statsLine.isEmpty {
                    Text(statsLine)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 32)
    }

    private var statsLine: String {
        var parts: [String] = []
        if workout.duration > 0 {
            parts.append(formattedDuration(workout.duration))
        }
        if let d = workout.distance, d > 0 {
            parts.append(String(format: "%.1f km", d))
        }
        return parts.joined(separator: " · ")
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
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
    func addWorkout(type: WorkoutType, daysAgo: Int, minutes: Double, distance: Double? = nil) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let workout = Workout(type: type, startDate: date, duration: minutes * 60, distance: distance)
        context.insert(workout)
    }
    addWorkout(type: .strength, daysAgo: 0, minutes: 45)
    addWorkout(type: .running, daysAgo: 1, minutes: 30, distance: 5.2)
    addWorkout(type: .yoga, daysAgo: 3, minutes: 25)
    addWorkout(type: .cycling, daysAgo: 4, minutes: 50, distance: 18.4)
    return NavigationStack {
        CalendarView()
    }
    .modelContainer(container)
}
