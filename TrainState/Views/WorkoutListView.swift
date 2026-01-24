import SwiftUI
import SwiftData
import HealthKit

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    @State private var showingAddWorkout = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    private let maxVisibleWorkouts = 250
    @State private var showAllWorkouts = false
    private let refreshCooldownInterval: TimeInterval = 30
    @State private var categorySheetWorkout: Workout?
    @State private var selectedFilter: WorkoutFilter = .all

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        workoutList
                    }
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refreshData() }
                    } label: {
                        let label = Group {
                            if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                        }
                        .padding(12)
                        label
                    }
                    .disabled(isRefreshing)
                    .buttonStyle(ScaleButtonStyle())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Filter by Type") {
                            ForEach(WorkoutFilter.allCases) { filter in
                                Button {
                                    withAnimation { selectedFilter = filter }
                                } label: {
                                    HStack {
                                        Label(filter.rawValue, systemImage: filter.systemImage)
                                        if selectedFilter == filter {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        let label = Image(systemName: selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .padding(12)
                        label
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddWorkout = true } label: {
                        let label = Image(systemName: "plus")
                            .padding(12)
                        label
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .sheet(isPresented: $showingAddWorkout) { AddWorkoutView() }
            .sheet(item: $categorySheetWorkout) { workout in
                CategorySelectionSheet(workout: workout)
            }
            .refreshable { await refreshData() }
        }
    }

    private var workoutList: some View {
        List {
            ForEach(groupedVisibleWorkouts, id: \.date) { entry in
                Section(
                    header: WeekdaySectionHeader(
                        date: entry.date,
                        workoutCount: entry.items.count,
                        isToday: Calendar.current.isDateInToday(entry.date)
                    )
                ) {
                    if entry.items.isEmpty {
                        Text("No workouts")
                            .textStyle(SecondaryText())
                            .font(style: .subheadline)
                    } else {
                        ForEach(entry.items, id: \.id) { workout in
                            WeeklyWorkoutRow(
                                workout: workout,
                                onEditCategories: { categorySheetWorkout = workout }
                            )
                        }
                    }
                }
            }
            if filteredWorkouts.count > maxVisibleWorkouts {
                Section {
                    Button {
                        withAnimation { showAllWorkouts.toggle() }
                    } label: {
                        let label = Text(showAllWorkouts ? "Show recent workouts only" : "Show all \(filteredWorkouts.count) workouts")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                        label
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: ViewConstants.spacingCompact, leading: ViewConstants.paddingStandard, bottom: ViewConstants.paddingStandard, trailing: ViewConstants.paddingStandard))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var filteredWorkouts: [Workout] {
        if selectedFilter == .all {
            return workouts
        }
        guard let filterType = selectedFilter.workoutType else { return workouts }
        return workouts.filter { $0.type == filterType }
    }
    
    private var visibleWorkouts: [Workout] {
        let filtered = filteredWorkouts
        guard !showAllWorkouts else { return filtered }
        return Array(filtered.prefix(maxVisibleWorkouts))
    }

    private var groupedVisibleWorkouts: [(date: Date, items: [Workout])] {
        let grouped = Dictionary(grouping: visibleWorkouts) { Calendar.current.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    private func refreshData(forceImport: Bool = false) async {
        guard !isRefreshing else { return }
        if let last = lastRefreshTime, Date().timeIntervalSince(last) < refreshCooldownInterval { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshTime = Date()
        }

        do { try await HealthKitManager.shared.requestAuthorizationIfNeeded() } catch { }
        await NetworkManager.shared.refreshNetworkStatus()

        if NetworkManager.shared.isSafeToUseData || forceImport {
            do {
                let count = try await HealthKitManager.shared.importNewWorkouts(context: modelContext)
            } catch {
            }
        } else {
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    let context = container.mainContext
    let calendar = Calendar.current
    
    let strength = WorkoutCategory(name: "Strength", color: "#8E44AD", workoutType: .strength)
    let running = WorkoutCategory(name: "Running", color: "#2E86DE", workoutType: .running)
    let yoga = WorkoutCategory(name: "Yoga", color: "#27AE60", workoutType: .yoga)
    let upperBody = WorkoutSubcategory(name: "Upper Body")
    strength.addSubcategory(upperBody)
    
    context.insert(strength)
    context.insert(running)
    context.insert(yoga)
    context.insert(upperBody)
    
    func addWorkout(
        type: WorkoutType,
        daysAgo: Int,
        duration: TimeInterval,
        distance: Double? = nil,
        categories: [WorkoutCategory]
    ) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let workout = Workout(type: type, startDate: date, duration: duration, distance: distance, categories: categories)
        context.insert(workout)
    }
    
    addWorkout(type: .running, daysAgo: 0, duration: 1800, distance: 4200, categories: [running])
    addWorkout(type: .strength, daysAgo: 0, duration: 2700, categories: [strength])
    addWorkout(type: .yoga, daysAgo: 1, duration: 1500, categories: [yoga])
    addWorkout(type: .running, daysAgo: 2, duration: 2100, distance: 5000, categories: [running])
    addWorkout(type: .strength, daysAgo: 3, duration: 3600, categories: [strength])
    
    return WorkoutListView().modelContainer(container)
}
