import SwiftUI
import SwiftData
import Charts

// MARK: - Supporting Types
enum WeekDisplayMode: String, CaseIterable, Identifiable {
    case lastSevenDays = "Last 7 Days"
    case calendarWeek = "This Week (Mon-Sun)"
    
    var id: String { rawValue }
}

struct DailyWorkoutSummary: Identifiable {
    let id = UUID()
    let date: Date
    let runningDuration: TimeInterval
    let runningDistance: Double
    let strengthDuration: TimeInterval
    let strengthCalories: Double
    
    var hasAnyActivity: Bool {
        runningDuration > 0 || runningDistance > 0 || strengthDuration > 0 || strengthCalories > 0
    }
    
    var totalDuration: TimeInterval {
        runningDuration + strengthDuration
    }
    
    var totalCalories: Double {
        strengthCalories
    }
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedWeekDisplayMode: WeekDisplayMode = .lastSevenDays
    @State private var cachedFilteredWorkouts: (running: [Workout], strength: [Workout]) = (running: [], strength: [])
    @State private var cachedDailySummaries: [DailyWorkoutSummary] = []
    @State private var lastWorkoutsHash: Int = 0
    @State private var lastWeekDisplayMode: WeekDisplayMode = .lastSevenDays
    @State private var showingPremiumPaywall = false
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Week Display Mode Picker - Show for all users
                        Picker("Week Display", selection: $selectedWeekDisplayMode) {
                            ForEach(WeekDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .disabled(!purchaseManager.hasActiveSubscription)
                        .opacity(purchaseManager.hasActiveSubscription ? 1.0 : 0.6)
                        
                        if purchaseManager.hasActiveSubscription {
                            // Premium Content
                            // Last Logged Subcategories
                            NavigationLink {
                                SubcategoryLastLoggedView()
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "clock.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Last Logged Subcategories")
                                            .font(.headline)
                                        Text("Track when you last performed each exercise")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            
                            // Weekly Summary Card
                            WeeklySummaryCard(filteredWorkouts: cachedFilteredWorkouts)
                                .containerRelativeFrame(.horizontal)
                            
                            // Activity Chart
                            ActivityChartView(dailySummaries: cachedDailySummaries)
                                .frame(height: 220)
                                .containerRelativeFrame(.horizontal)
                            
                            // Daily Breakdown
                            DailyBreakdownView(dailySummaries: cachedDailySummaries, calendar: calendar)
                                .containerRelativeFrame(.horizontal)
                            
                            // Activity Streaks
                            StreakCardView(
                                currentStreak: calculateCurrentStreak(workouts: workouts, calendar: calendar),
                                longestStreak: calculateLongestStreak(workouts: workouts, calendar: calendar)
                            )
                            .containerRelativeFrame(.horizontal)
                        } else {
                            // Free Content - Basic Overview
                            VStack(spacing: 20) {
                                // Basic Weekly Summary (limited)
                                WeeklySummaryCard(filteredWorkouts: cachedFilteredWorkouts)
                                    .containerRelativeFrame(.horizontal)
                                
                                // Premium Upsell Card
                                Button(action: {
                                    showingPremiumPaywall = true
                                }) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)
                                        
                                        Text("Unlock Advanced Analytics")
                                            .font(.title2.weight(.bold))
                                            .multilineTextAlignment(.center)
                                        
                                        Text("Get detailed insights with charts, streaks, daily breakdowns, and more")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                        
                                        HStack {
                                            Image(systemName: "star.fill")
                                            Text("Upgrade to Premium")
                                                .font(.headline)
                                        }
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    .padding(24)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Analytics")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)

                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            updateCachedData()
        }
        .onChange(of: workouts) { _, _ in
            updateCachedData()
        }
        .onChange(of: selectedWeekDisplayMode) { _, _ in
            updateCachedData()
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            AnalyticsPremiumPaywallView(
                isPresented: $showingPremiumPaywall,
                onPurchase: {
                    Task {
                        if let product = purchaseManager.products.first(where: { $0.id == "Premium1Month" }) {
                            do {
                                try await purchaseManager.purchase(product)
                                showingPremiumPaywall = false
                            } catch {
                                print("Purchase failed:", error)
                            }
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - Data Processing
    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch selectedWeekDisplayMode {
        case .lastSevenDays:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
            return (sevenDaysAgo, calendar.date(byAdding: .day, value: 1, to: startOfToday)!)
            
        case .calendarWeek:
            let weekday = calendar.component(.weekday, from: startOfToday)
            let daysToSubtract = (weekday + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfToday)!
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
            return (monday, calendar.date(byAdding: .day, value: 1, to: sunday)!)
        }
    }
    
    private var filteredWorkouts: (running: [Workout], strength: [Workout]) {
        let range = dateRange
        let filtered = workouts.filter { $0.startDate >= range.start && $0.startDate < range.end }
        return (
            running: filtered.filter { $0.type == .running },
            strength: filtered.filter { $0.type == .strength }
        )
    }
    
    private var dailySummaries: [DailyWorkoutSummary] {
        let range = dateRange
        var summaries: [DailyWorkoutSummary] = []
        
        var currentDate = range.start
        while currentDate < range.end {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let runningWorkouts = filteredWorkouts.running.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            let strengthWorkouts = filteredWorkouts.strength.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            
            let runningDuration = runningWorkouts.reduce(0) { $0 + $1.duration }
            let runningDistance = runningWorkouts.compactMap { $0.distance }.reduce(0, +)
            
            let strengthDuration = strengthWorkouts.reduce(0) { $0 + $1.duration }
            let strengthCalories = strengthWorkouts.compactMap { $0.calories }.reduce(0, +)
            
            summaries.append(DailyWorkoutSummary(
                date: dayStart,
                runningDuration: runningDuration,
                runningDistance: runningDistance,
                strengthDuration: strengthDuration,
                strengthCalories: strengthCalories
            ))
            
            currentDate = dayEnd
        }
        
        return summaries.sorted { $0.date > $1.date }
    }
    
    private func calculateCurrentStreak(workouts: [Workout], calendar: Calendar) -> Int {
        guard !workouts.isEmpty else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let uniqueWorkoutDays = Array(Set(workouts.map { calendar.startOfDay(for: $0.startDate) })).sorted().reversed()
        
        guard !uniqueWorkoutDays.isEmpty else { return 0 }
        
        var currentStreak = 0
        var expectedDate: Date
        
        if uniqueWorkoutDays.first == today {
            currentStreak = 1
            expectedDate = yesterday
        } else if uniqueWorkoutDays.first == yesterday {
            currentStreak = 1
            expectedDate = calendar.date(byAdding: .day, value: -1, to: yesterday)!
        } else {
            return 0
        }
        
        for day in uniqueWorkoutDays.dropFirst() {
            if calendar.isDate(day, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if day < expectedDate {
                break
            }
        }
        
        return currentStreak
    }
    
    private func calculateLongestStreak(workouts: [Workout], calendar: Calendar) -> Int {
        guard !workouts.isEmpty else { return 0 }
        
        let uniqueWorkoutDays = Array(Set(workouts.map { calendar.startOfDay(for: $0.startDate) })).sorted()
        
        guard !uniqueWorkoutDays.isEmpty else { return 0 }
        
        var maxStreak = 0
        var currentStreak = 0
        
        for i in 0..<uniqueWorkoutDays.count {
            if i == 0 {
                currentStreak = 1
            } else {
                let previousDay = uniqueWorkoutDays[i-1]
                let currentDay = uniqueWorkoutDays[i]
                if let daysDifference = calendar.dateComponents([.day], from: previousDay, to: currentDay).day, daysDifference == 1 {
                    currentStreak += 1
                } else {
                    currentStreak = 1
                }
            }
            maxStreak = max(maxStreak, currentStreak)
        }
        
        return maxStreak
    }
    
    // MARK: - Cache Management
    private func updateCachedData() {
        let newHash = workouts.map { $0.id }.hashValue
        let hasWorkoutsChanged = newHash != lastWorkoutsHash
        let hasDisplayModeChanged = selectedWeekDisplayMode != lastWeekDisplayMode
        
        if hasWorkoutsChanged || hasDisplayModeChanged || cachedDailySummaries.isEmpty {
            lastWorkoutsHash = newHash
            lastWeekDisplayMode = selectedWeekDisplayMode
            cachedFilteredWorkouts = filteredWorkouts
            cachedDailySummaries = dailySummaries
        }
    }
}

// MARK: - Supporting Views
struct WeeklySummaryCard: View {
    let filteredWorkouts: (running: [Workout], strength: [Workout])
    
    var body: some View {
        VStack(spacing: 20) {
            // Running Summary
            WorkoutTypeSummary(
                title: "Running",
                workouts: filteredWorkouts.running,
                icon: "figure.run",
                color: .blue
            )
            
            Divider()
                .background(.quaternary)
            
            // Strength Training Summary
            WorkoutTypeSummary(
                title: "Strength Training",
                workouts: filteredWorkouts.strength,
                icon: "dumbbell.fill",
                color: .purple
            )
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct WorkoutTypeSummary: View {
    let title: String
    let workouts: [Workout]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(color)
            }
            
            if workouts.isEmpty {
                Text("No \(title.lowercased()) workouts this week")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatView(icon: icon, title: "Workouts", value: "\(workouts.count)", color: color)
                    StatView(icon: "clock.fill", title: "Duration", value: formatDuration(workouts.reduce(0) { $0 + $1.duration }), color: color)
                    
                    if title == "Running" {
                        let totalDistance = workouts.compactMap { $0.distance }.reduce(0, +)
                        if totalDistance > 0 {
                            StatView(icon: "figure.run", title: "Distance", value: formatDistance(totalDistance), color: color)
                        }
                    } else {
                        let calories = workouts.compactMap { $0.calories }.reduce(0, +)
                        if calories > 0 {
                            StatView(icon: "flame.fill", title: "Calories", value: "\(Int(calories))", color: color)
                        }
                    }
                }
            }
        }
    }
}

struct ActivityChartView: View {
    let dailySummaries: [DailyWorkoutSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Overview")
                .font(.title3.bold())
                .padding(.horizontal)
            
            Chart {
                ForEach(dailySummaries) { summary in
                    BarMark(
                        x: .value("Date", summary.date, unit: .day),
                        y: .value("Duration", summary.totalDuration / 60)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(8)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel("\(value.index * 30)m")
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct DailyBreakdownView: View {
    let dailySummaries: [DailyWorkoutSummary]
    let calendar: Calendar
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Floating Title
            Text("Daily Breakdown")
                .font(.title3.bold())
                .padding(.top, 8)
                .padding(.horizontal, 28)
                .shadow(color: .primary.opacity(0.08), radius: 8, y: 2)
                .zIndex(1)
            
            if dailySummaries.isEmpty {
                Text("No workouts in this period")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 16) {
                    ForEach(dailySummaries) { summary in
                        DailySummaryRowModern(summary: summary, calendar: calendar)
                    }
                }
                .padding(.bottom, 4)
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .primary.opacity(0.06), radius: 24, y: 8)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.18), Color.blue.opacity(0.08)]),
                        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 0)
        .padding(.bottom, 8)
    }
}

// Modern, glassy row for daily summary
struct DailySummaryRowModern: View {
    let summary: DailyWorkoutSummary
    let calendar: Calendar
    
    var body: some View {
        VStack(spacing: 18) {
            // Header Section
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: summary.date) - 1])
                        .font(.headline)
                    Text(summary.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if summary.hasAnyActivity {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text(formatDuration(summary.totalDuration))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.blue)
                    }
                }
            }
            if summary.hasAnyActivity {
                VStack(spacing: 14) {
                    if summary.runningDuration > 0 {
                        ActivityMetricRow(
                            title: "Running",
                            icon: "figure.run",
                            color: .blue,
                            primaryMetric: formatDistance(summary.runningDistance),
                            secondaryMetric: formatDuration(summary.runningDuration)
                        )
                    }
                    if summary.strengthDuration > 0 {
                        ActivityMetricRow(
                            title: "Strength",
                            icon: "dumbbell.fill",
                            color: .purple,
                            primaryMetric: "\(Int(summary.strengthCalories)) cal",
                            secondaryMetric: formatDuration(summary.strengthDuration)
                        )
                    }
                }
            } else {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.secondary)
                    Text("Rest Day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .primary.opacity(0.08), radius: 10, y: 4)
    }
}

struct ActivityMetricRow: View {
    let title: String
    let icon: String
    let color: Color
    let primaryMetric: String
    let secondaryMetric: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon and Title
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
            
            Spacer()
            
            // Metrics
            VStack(alignment: .trailing, spacing: 4) {
                Text(primaryMetric)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(secondaryMetric)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ActivityIndicator: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

struct StreakCardView: View {
    let currentStreak: Int
    let longestStreak: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Current Streak", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(currentStreak) days")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label("Longest Streak", systemImage: "trophy.fill")
                    .foregroundStyle(.yellow)
                Spacer()
                Text("\(longestStreak) days")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct StatView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helper Functions
private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = Int(duration) / 60 % 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else if minutes > 0 {
        return "\(minutes)m"
    } else {
        let seconds = Int(duration) % 60
        return seconds > 0 ? "\(seconds)s" : "0m"
    }
}

private func formatDistance(_ distance: Double) -> String {
    let kilometers = distance / 1000
    if kilometers >= 1 {
        return String(format: "%.1f km", kilometers)
    } else {
        return String(format: "%.0f m", distance)
    }
}

// Preview helper function
private func createSampleWorkout(type: WorkoutType, daysAgo: Int, duration: TimeInterval, calories: Double?) -> Workout {
    let today = Date()
    let calendar = Calendar.current
    let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
    return Workout(type: type, startDate: date, duration: duration, calories: calories)
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
        configurations: config
    )
    
    // Add sample workouts to the context
    let sampleWorkouts = [
        // Last 7 Days
        createSampleWorkout(type: .running, daysAgo: 0, duration: 1800, calories: 250), // Today
        createSampleWorkout(type: .strength, daysAgo: 1, duration: 3600, calories: 300), // Yesterday
        createSampleWorkout(type: .running, daysAgo: 2, duration: 2400, calories: 350),
        createSampleWorkout(type: .strength, daysAgo: 3, duration: 3000, calories: 280),
        createSampleWorkout(type: .running, daysAgo: 5, duration: 1500, calories: 200),
        
        // Older workouts for streak testing
        createSampleWorkout(type: .running, daysAgo: 8, duration: 2200, calories: 320),
        createSampleWorkout(type: .strength, daysAgo: 10, duration: 3300, calories: 290),
        createSampleWorkout(type: .running, daysAgo: 15, duration: 1800, calories: 260)
    ]
    
    for workout in sampleWorkouts {
        container.mainContext.insert(workout)
    }
    
    return AnalyticsView()
        .modelContainer(container)
}

// MARK: - Analytics Premium Paywall View
struct AnalyticsPremiumPaywallView: View {
    @Binding var isPresented: Bool
    let onPurchase: () -> Void
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingSubscriptionPage = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Unlock Advanced Analytics")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Get detailed insights into your fitness progress with comprehensive charts and analytics")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Features
                    VStack(spacing: 20) {
                        AnalyticsFeatureRow(
                            icon: "chart.bar.fill",
                            title: "Interactive Charts",
                            description: "Visualize your progress with beautiful charts and graphs"
                        )
                        AnalyticsFeatureRow(
                            icon: "flame.fill",
                            title: "Activity Streaks",
                            description: "Track your current and longest workout streaks"
                        )
                        AnalyticsFeatureRow(
                            icon: "calendar.badge.clock",
                            title: "Daily Breakdown",
                            description: "See detailed daily activity summaries and patterns"
                        )
                        AnalyticsFeatureRow(
                            icon: "clock.fill",
                            title: "Last Logged Tracking",
                            description: "Track when you last performed each exercise"
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Purchase Button
                    Button(action: {
                        showingSubscriptionPage = true
                    }) {
                        Text("Unlock Premium Analytics")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Premium Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSubscriptionPage) {
                PremiumView()
            }
        }
    }
}

private struct AnalyticsFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
} 