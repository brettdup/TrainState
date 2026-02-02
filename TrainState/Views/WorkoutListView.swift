import SwiftUI
import SwiftData
import RevenueCatUI

struct WorkoutListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var showingPaywall = false
    @State private var selectedFilter: WorkoutFilter = .all

    private var canAddWorkout: Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || workouts.count < PremiumLimits.freeWorkoutLimit
    }

    private var showLimitsCard: Bool {
        purchaseManager.hasCompletedInitialPremiumCheck && !purchaseManager.hasActiveSubscription
    }

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

                if groupedVisibleWorkouts.isEmpty {
                    ScrollView {
                        VStack(spacing: 24) {
                            ContentUnavailableView {
                                Label("No Workouts", systemImage: "figure.run")
                            } description: {
                                Text("Tap + to log your first workout.")
                            }
                            .padding(.top, 40)

                            if showLimitsCard {
                                limitsCard
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if showLimitsCard {
                                limitsCard
                            }
                            summaryCard
                            ForEach(groupedVisibleWorkouts, id: \.date) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(sectionHeaderTitle(for: entry.date))
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)

                                    ForEach(entry.items, id: \.id) { workout in
                                        NavigationLink {
                                            WorkoutDetailView(workout: workout)
                                        } label: {
                                            WorkoutRowView(workout: workout)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                if selectedFilter == filter {
                                    Label(filter.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(filter.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    Button {
                        if canAddWorkout {
                            showingAddWorkout = true
                        } else {
                            Task {
                                await purchaseManager.loadProducts()
                                await purchaseManager.updatePurchasedProducts()
                                showingPaywall = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .sheet(isPresented: $showingPaywall) {
                if let offering = purchaseManager.offerings?.current {
                    PaywallView(offering: offering)
                } else {
                    PaywallPlaceholderView(onDismiss: { showingPaywall = false })
                }
            }
        }
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Free Tier Limits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                limitRow(
                    label: "Workouts",
                    used: workouts.count,
                    limit: PremiumLimits.freeWorkoutLimit
                )
                limitRow(
                    label: "Categories",
                    used: categories.count,
                    limit: PremiumLimits.freeCategoryLimit
                )
                Text("2 subcategories per category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showingPaywall = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Premium")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private func limitRow(label: String, used: Int, limit: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(used)/\(limit)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(used >= limit ? .red : .primary)
        }
    }

    private var summaryCard: some View {
        let summary = weeklySummary(for: filteredWorkouts)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(summary.count) workouts · \(summary.duration)")
                    .font(.headline)
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 32)
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
}

// MARK: - Workout Row (glass card style, matches CalendarView)
private struct WorkoutRowView: View {
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

                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if !categoryAndSubcategoryNames.isEmpty {
                    Text(categoryAndSubcategoryNames)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

    private var categoryAndSubcategoryNames: String {
        let catNames = workout.categories?.map(\.name) ?? []
        let subNames = workout.subcategories?.map(\.name) ?? []
        return (catNames + subNames).joined(separator: ", ")
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

struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
        let context = container.mainContext
        let calendar = Calendar.current

        let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
        let pull = WorkoutCategory(name: "Pull", color: "#4ECDC4", workoutType: .strength)
        let legs = WorkoutCategory(name: "Legs", color: "#45B7D1", workoutType: .strength)
        let upper = WorkoutCategory(name: "Upper Body", color: "#96CEB4", workoutType: .strength)
        let endurance = WorkoutCategory(name: "Endurance", color: "#FFEAA7", workoutType: .running)
        context.insert(push)
        context.insert(pull)
        context.insert(legs)
        context.insert(upper)
        context.insert(endurance)

        let benchPress = WorkoutSubcategory(name: "Bench Press", category: push)
        context.insert(benchPress)

        let squat = WorkoutSubcategory(name: "Squat", category: legs)
        context.insert(squat)

        let tempo = WorkoutSubcategory(name: "Tempo", category: endurance)
        context.insert(tempo)

        func addWorkout(type: WorkoutType, daysAgo: Int, durationMinutes: Double, distance: Double? = nil, categories: [WorkoutCategory] = [], subcategories: [WorkoutSubcategory] = []) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let workout = Workout(type: type, startDate: date, duration: durationMinutes * 60, distance: distance, categories: categories.isEmpty ? nil : categories, subcategories: subcategories.isEmpty ? nil : subcategories)
            context.insert(workout)
        }

        addWorkout(type: .running, daysAgo: 0, durationMinutes: 45, distance: 6.2, categories: [endurance], subcategories: [tempo])
        addWorkout(type: .strength, daysAgo: 0, durationMinutes: 60, categories: [push, pull], subcategories: [benchPress])
        addWorkout(type: .yoga, daysAgo: 1, durationMinutes: 30)
        addWorkout(type: .cycling, daysAgo: 3, durationMinutes: 50, distance: 18.4)
        addWorkout(type: .strength, daysAgo: 2, durationMinutes: 45, categories: [legs], subcategories: [squat])
        addWorkout(type: .strength, daysAgo: 4, durationMinutes: 50, categories: [upper])

        return NavigationStack {
            WorkoutListView()
        }
        .modelContainer(container)
    }
}
