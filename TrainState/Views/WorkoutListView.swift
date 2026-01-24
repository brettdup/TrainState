import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @State private var showingAddWorkout = false
    @State private var selectedFilter: WorkoutFilter = .all
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    private let refreshCooldownInterval: TimeInterval = 30
    @State private var didRequestHealthAuth = false

    var body: some View {
        NavigationStack {
            listContent
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refreshData() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .refreshable {
                await refreshData()
            }
            .task {
                guard !didRequestHealthAuth else { return }
                didRequestHealthAuth = true
                do { try await HealthKitManager.shared.requestAuthorizationIfNeeded() } catch { }
            }
        }
    }

    private var summaryHeader: some View {
        let summary = weeklySummary(for: filteredWorkouts)
        return VStack(alignment: .leading, spacing: 6) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(summary.count) workouts • \(summary.duration)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.systemImage)
                                .font(.caption)
                            Text(filter.rawValue)
                                .font(.caption)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(selectedFilter == filter ? Color.primary.opacity(0.1) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(selectedFilter == filter ? 0.25 : 0.12), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var listContent: some View {
        List {
            Section {
                summaryHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                filterChips
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            .listRowBackground(Color.clear)

            if groupedVisibleWorkouts.isEmpty {
                Text("No workouts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedVisibleWorkouts, id: \.date) { entry in
                    Section {
                        ForEach(entry.items, id: \.id) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutRowBasicView(workout: workout)
                            }
                        }
                    } header: {
                        Text(sectionHeaderTitle(for: entry.date))
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var filteredWorkouts: [Workout] {
        if selectedFilter == .all {
            return workouts
        }
        guard let filterType = selectedFilter.workoutType else { return workouts }
        return workouts.filter { $0.type == filterType }
    }

    private var groupedVisibleWorkouts: [(date: Date, items: [Workout])] {
        let grouped = Dictionary(grouping: filteredWorkouts) { Calendar.current.startOfDay(for: $0.startDate) }
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

    private func weeklySummary(for workouts: [Workout]) -> (count: Int, duration: String) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return (workouts.count, formattedDuration(0))
        }
        let weekWorkouts = workouts.filter { weekInterval.contains($0.startDate) }
        let totalDuration = weekWorkouts.reduce(0) { $0 + $1.duration }
        return (weekWorkouts.count, formattedDuration(totalDuration))
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }

    private func refreshData() async {
        guard !isRefreshing else { return }
        if let last = lastRefreshTime, Date().timeIntervalSince(last) < refreshCooldownInterval { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshTime = Date()
        }

        do { try await HealthKitManager.shared.requestAuthorizationIfNeeded() } catch { }
        do { _ = try await HealthKitManager.shared.importNewWorkouts(context: modelContext) } catch { }
    }
}

private struct WorkoutRowBasicView: View {
    let workout: Workout

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: workout.type.systemImage)
                .foregroundStyle(workout.type.tintColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.headline)
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if workout.duration > 0 {
                    Text(formattedDuration(workout.duration))
                        .font(.subheadline)
                }
                if let distance = workout.distance, distance > 0 {
                    Text("\(distance, format: .number.precision(.fractionLength(1))) km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let context = container.mainContext
    let calendar = Calendar.current

    func addWorkout(type: WorkoutType, daysAgo: Int, durationMinutes: Double, distance: Double? = nil) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let workout = Workout(type: type, startDate: date, duration: durationMinutes * 60, distance: distance)
        context.insert(workout)
    }

    addWorkout(type: .running, daysAgo: 0, durationMinutes: 45, distance: 6.2)
    addWorkout(type: .strength, daysAgo: 0, durationMinutes: 60)
    addWorkout(type: .yoga, daysAgo: 1, durationMinutes: 30)
    addWorkout(type: .cycling, daysAgo: 3, durationMinutes: 50, distance: 18.4)

    return WorkoutListView()
        .modelContainer(container)
}
