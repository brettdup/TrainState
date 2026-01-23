import SwiftUI
import SwiftData
import HealthKit

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    @State private var showingAddWorkout = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    @State private var showingForceSyncConfirm = false
    @State private var syncStatus: String = ""
    private let maxVisibleWorkouts = 250
    @State private var showAllWorkouts = false
    private let refreshCooldownInterval: TimeInterval = 30
    @State private var categorySheetWorkout: Workout?

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                List {
                    headerSection
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
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
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
                    if workouts.count > maxVisibleWorkouts {
                        Section {
                            Button(showAllWorkouts ? "Show recent workouts only" : "Show all \(workouts.count) workouts") {
                                withAnimation { showAllWorkouts.toggle() }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refreshData() }
                    } label: {
                        if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isRefreshing)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddWorkout = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddWorkout) { AddWorkoutView() }
            .sheet(item: $categorySheetWorkout) { workout in
                CategorySelectionSheet(workout: workout)
            }
            .refreshable { await refreshData() }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Your training").font(.headline)
                    Spacer()
                    if !NetworkManager.shared.isSafeToUseData {
                        Button("Force Sync") { showingForceSyncConfirm = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                    } else {
                        Button("Sync") { Task { await refreshData() } }
                    }
                }
                if isRefreshing {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.9)
                        Text(syncStatus.isEmpty ? "Syncing..." : syncStatus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if !syncStatus.isEmpty {
                    Text(syncStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Force Sync on Cellular?", isPresented: $showingForceSyncConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Force Sync", role: .destructive) { Task { await refreshData(forceImport: true) } }
        } message: {
            Text("This may use mobile data. Continue?")
        }
    }

    private var visibleWorkouts: [Workout] {
        guard !showAllWorkouts else { return workouts }
        return Array(workouts.prefix(maxVisibleWorkouts))
    }

    private var groupedVisibleWorkouts: [(date: Date, items: [Workout])] {
        let grouped = Dictionary(grouping: visibleWorkouts) { Calendar.current.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    private func refreshData(forceImport: Bool = false) async {
        guard !isRefreshing else { return }
        if let last = lastRefreshTime, Date().timeIntervalSince(last) < refreshCooldownInterval { return }

        isRefreshing = true
        syncStatus = "Syncing..."
        defer {
            isRefreshing = false
            lastRefreshTime = Date()
            syncStatus = ""
        }

        do { try await HealthKitManager.shared.requestAuthorizationIfNeeded() } catch { }
        await NetworkManager.shared.refreshNetworkStatus()

        if NetworkManager.shared.isSafeToUseData || forceImport {
            do {
                let count = try await HealthKitManager.shared.importNewWorkouts(context: modelContext)
                syncStatus = count > 0 ? "Imported \(count) new" : "No new workouts"
            } catch {
                syncStatus = "Sync failed"
            }
        } else {
            syncStatus = "Waiting for Wi‑Fi"
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
    return WorkoutListView().modelContainer(container)
}
