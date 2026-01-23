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
    
    var hasAnyActivity: Bool {
        runningDuration > 0 || runningDistance > 0 || strengthDuration > 0
    }
    
    var totalDuration: TimeInterval {
        runningDuration + strengthDuration
    }
    
    
}

// MARK: - Analytics View (Modern Redesign)
struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedWeekDisplayMode: WeekDisplayMode = .lastSevenDays
    @State private var showingPremiumPaywall = false
    @State private var cachedData: AnalyticsCachedData?
    @State private var lastUpdateTime: Date = Date()
    @State private var isLoadingData = false
    private let calendar = Calendar.current

    // Optimized query for workouts
    @Query private var allWorkouts: [Workout]

    // Date range logic
    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        switch selectedWeekDisplayMode {
        case .lastSevenDays:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return (sevenDaysAgo, tomorrow)
        case .calendarWeek:
            let weekday = calendar.component(.weekday, from: startOfToday)
            let daysSinceMonday = (weekday + 5) % 7
            let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfToday)!
            let nextMonday = calendar.date(byAdding: .day, value: 7, to: thisMonday)!
            return (thisMonday, nextMonday)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isLoadingData {
                        HStack {
                            ProgressView()
                            Text("Loading analytics...")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    // Hero Card
                    HeroStatsCard(
                        totalWorkouts: (cachedData?.filteredWorkouts.running.count ?? 0) + (cachedData?.filteredWorkouts.strength.count ?? 0),
                        currentStreak: cachedData?.currentStreak ?? 0
                    )
                    .padding(.horizontal)

                    // Total Stats Card
                    if let cachedData = cachedData {
                        TotalStatsRow(
                            totalDistance: cachedData.filteredWorkouts.running.compactMap { $0.distance }.reduce(0, +),
                            totalStrengthMinutes: Int(cachedData.filteredWorkouts.strength.reduce(0) { $0 + $1.duration } / 60)
                        )
                        .padding(.horizontal)
                    }

                    // Time Period Picker
                    TimePeriodPickerCard(selectedMode: $selectedWeekDisplayMode)
                        .padding(.horizontal)

                    // Activity Chart
                    ActivityChartCard(dailySummaries: cachedData?.dailySummaries ?? [])
                        .padding(.horizontal)

                    // Workout Type Breakdown
                    WorkoutTypeBreakdownRow(cachedData: cachedData)
                        .padding(.horizontal)

                    // Daily Breakdown
                    DailyBreakdownCard(dailySummaries: cachedData?.dailySummaries ?? [], calendar: calendar)
                        .padding(.horizontal)

                    // Last Category Viewed (tappable card)
                    NavigationLink {
                        SubcategoryLastLoggedView()
                            .navigationTitle("Last Category Viewed")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text("Last Category Viewed")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .primary.opacity(0.06), radius: 8, y: 4)
                        .padding(.horizontal)
                    }

                    // Premium Upsell
                    if !purchaseManager.hasActiveSubscription {
                        PremiumUpsellCard { showingPremiumPaywall = true }
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(BackgroundView().ignoresSafeArea())
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
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
            .onAppear { updateCachedDataIfNeeded() }
            .onChange(of: allWorkouts) { _, _ in updateCachedDataIfNeeded() }
            .onChange(of: selectedWeekDisplayMode) { _, _ in updateCachedDataIfNeeded() }
        }
    }

    // MARK: - Data Processing (unchanged)
    private func updateCachedDataIfNeeded() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        guard cachedData == nil || timeSinceLastUpdate > 1.0 else { return }
        lastUpdateTime = now
        isLoadingData = true
        Task.detached(priority: .userInitiated) {
            let newCachedData = await processAnalyticsData()
            await MainActor.run {
                cachedData = newCachedData
                isLoadingData = false
            }
        }
    }
    @MainActor
    private func processAnalyticsData() async -> AnalyticsCachedData {
        let range = dateRange
        let filtered = allWorkouts.filter { $0.startDate >= range.start && $0.startDate < range.end }
        let running = filtered.filter { $0.type == .running }
        let strength = filtered.filter { $0.type == .strength }
        let dailySummaries = await calculateDailySummaries(running: running, strength: strength, dateRange: range)
        let (currentStreak, longestStreak) = await calculateStreaks(workouts: allWorkouts)
        return AnalyticsCachedData(
            filteredWorkouts: (running: running, strength: strength),
            dailySummaries: dailySummaries,
            currentStreak: currentStreak,
            longestStreak: longestStreak
        )
    }
    
    private func calculateDailySummaries(
        running: [Workout],
        strength: [Workout],
        dateRange: (start: Date, end: Date)
    ) async -> [DailyWorkoutSummary] {
        // Group workouts by day for efficient processing
        let runningByDay = Dictionary(grouping: running) { workout in
            calendar.startOfDay(for: workout.startDate)
        }
        
        let strengthByDay = Dictionary(grouping: strength) { workout in
            calendar.startOfDay(for: workout.startDate)
        }
        
        var summaries: [DailyWorkoutSummary] = []
        var currentDate = dateRange.start
        
        while currentDate < dateRange.end {
            let dayStart = calendar.startOfDay(for: currentDate)
            let runningWorkouts = runningByDay[dayStart] ?? []
            let strengthWorkouts = strengthByDay[dayStart] ?? []
            
            let runningDuration = runningWorkouts.reduce(0) { $0 + $1.duration }
            let runningDistance = runningWorkouts.compactMap { $0.distance }.reduce(0, +)
            let strengthDuration = strengthWorkouts.reduce(0) { $0 + $1.duration }
            
            summaries.append(DailyWorkoutSummary(
                date: dayStart,
                runningDuration: runningDuration,
                runningDistance: runningDistance,
                strengthDuration: strengthDuration
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return summaries.sorted { $0.date > $1.date }
    }
    
    private func calculateStreaks(workouts: [Workout]) async -> (current: Int, longest: Int) {
        guard !workouts.isEmpty else { return (0, 0) }
        
        // Get unique workout days efficiently
        let uniqueWorkoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
        let sortedDays = Array(uniqueWorkoutDays).sorted()
        
        // Calculate current streak
        let currentStreak = calculateCurrentStreak(sortedDays: sortedDays)
        
        // Calculate longest streak
        let longestStreak = calculateLongestStreak(sortedDays: sortedDays)
        
        return (currentStreak, longestStreak)
    }
    
    private func calculateCurrentStreak(sortedDays: [Date]) -> Int {
        guard !sortedDays.isEmpty else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let reversedDays = sortedDays.reversed()
        
        guard !reversedDays.isEmpty else { return 0 }
        
        var currentStreak = 0
        var expectedDate: Date
        
        if reversedDays.first == today {
            currentStreak = 1
            expectedDate = yesterday
        } else if reversedDays.first == yesterday {
            currentStreak = 1
            expectedDate = calendar.date(byAdding: .day, value: -1, to: yesterday)!
        } else {
            return 0
        }
        
        for day in reversedDays.dropFirst() {
            if calendar.isDate(day, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if day < expectedDate {
                break
            }
        }
        
        return currentStreak
    }
    
    private func calculateLongestStreak(sortedDays: [Date]) -> Int {
        guard !sortedDays.isEmpty else { return 0 }
        
        var maxStreak = 0
        var currentStreak = 0
        
        for i in 0..<sortedDays.count {
            if i == 0 {
                currentStreak = 1
            } else {
                let previousDay = sortedDays[i-1]
                let currentDay = sortedDays[i]
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
}

// MARK: - Cached Data Structure
struct AnalyticsCachedData {
    let filteredWorkouts: (running: [Workout], strength: [Workout])
    let dailySummaries: [DailyWorkoutSummary]
    let currentStreak: Int
    let longestStreak: Int
}

// MARK: - Hero Stats Card
struct HeroStatsCard: View {
    let totalWorkouts: Int
    let currentStreak: Int
    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.blue)
                Text("\(totalWorkouts)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Total Workouts")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.orange)
                Text("\(currentStreak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Current Streak")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .appCard()
    }
}

// MARK: - Time Period Picker Card
struct TimePeriodPickerCard: View {
    @Binding var selectedMode: WeekDisplayMode
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Period")
                .font(.headline)
                .foregroundStyle(.primary)
            Picker("Week Display", selection: $selectedMode) {
                ForEach(WeekDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .appCard()
    }
}

// MARK: - Activity Chart Card
struct ActivityChartCard: View {
    let dailySummaries: [DailyWorkoutSummary]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity This Week")
                .font(.title3.bold())
            Chart {
                ForEach(dailySummaries) { summary in
                    BarMark(
                        x: .value("Date", summary.date, unit: .day),
                        y: .value("Duration", summary.totalDuration / 60)
                    )
                    .foregroundStyle(.blue)
                    .cornerRadius(6)
                }
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel("\(value.index * 30)m")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appCard()
        .appCard()
    }
}

// MARK: - Workout Type Breakdown Row
struct WorkoutTypeBreakdownRow: View {
    let cachedData: AnalyticsCachedData?
    var body: some View {
        HStack(spacing: 16) {
            let running = cachedData?.filteredWorkouts.running ?? []
            let runningDuration = running.reduce(0) { $0 + $1.duration }
            let runningDistance = running.compactMap { $0.distance }.reduce(0, +)
            AnalyticsWorkoutTypeCard(
                title: "Running",
                icon: "figure.run",
                color: Color.blue,
                count: running.count,
                duration: runningDuration,
                distance: runningDistance,
                calories: nil
            )
            let strength = cachedData?.filteredWorkouts.strength ?? []
            let strengthDuration = strength.reduce(0) { $0 + $1.duration }
            AnalyticsWorkoutTypeCard(
                title: "Strength",
                icon: "dumbbell.fill",
                color: Color.purple,
                count: strength.count,
                duration: strengthDuration,
                distance: nil,
                calories: nil
            )
        }
        .frame(maxHeight: 180)
    }
}

// MARK: - Analytics Workout Type Card
struct AnalyticsWorkoutTypeCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let duration: TimeInterval
    let distance: Double?
    let calories: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Workouts")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                
                HStack {
                    Text("Duration")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(duration))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                
                if let distance = distance, distance > 0 {
                    HStack {
                        Text("Distance")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatDistance(distance))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                
                if let calories = calories, calories > 0 {
                    HStack {
                        Text("Calories")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(calories))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

// MARK: - Total Stats Row
struct TotalStatsRow: View {
    let totalDistance: Double // in meters
    let totalStrengthMinutes: Int // in minutes
    
    var body: some View {
        ZStack {
            // Glassy background with border
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.08), radius: 16, y: 6)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1.2)
            HStack(spacing: 0) {
                statColumn(
                    icon: "figure.run",
                    iconColor: .blue,
                    value: formatDistance(totalDistance),
                    label: "Total Distance"
                )
                Spacer(minLength: 0)
                statColumn(
                    icon: "dumbbell.fill",
                    iconColor: .purple,
                    value: "\(totalStrengthMinutes) min",
                    label: "Strength Minutes"
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private func statColumn(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.13))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .accessibilityLabel(Text("\(label): \(value)"))
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Daily Breakdown Card
struct DailyBreakdownCard: View {
    let dailySummaries: [DailyWorkoutSummary]
    let calendar: Calendar
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.title3.bold())
            ForEach(dailySummaries) { summary in
                DailyBreakdownRow(summary: summary, calendar: calendar)
            }
        }
        .appCard()
    }
}

// MARK: - Premium Upsell Card
struct PremiumUpsellCard: View {
    let onTap: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Unlock Advanced Analytics")
                    .font(.headline)
            }
            Text("Get detailed insights, streaks, and interactive charts with Premium.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onTap) {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
        }
        .appCard()
    }
}

// MARK: - Feature Highlight
struct FeatureHighlight: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Legacy Supporting Views
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
        .appCard(padding: 20)
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
                            primaryMetric: formatDuration(summary.strengthDuration),
                            secondaryMetric: ""
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
    return Workout(type: type, startDate: date, duration: duration)
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
            configurations: config
        )

        // Add sample workouts to the context
        let sampleWorkouts = [
            // Last 7 Days
            createSampleWorkout(type: .running, daysAgo: 0, duration: 1800, calories: nil), // Today
            createSampleWorkout(type: .strength, daysAgo: 1, duration: 3600, calories: nil), // Yesterday
            createSampleWorkout(type: .running, daysAgo: 2, duration: 2400, calories: nil),
            createSampleWorkout(type: .strength, daysAgo: 3, duration: 3000, calories: nil),
            createSampleWorkout(type: .running, daysAgo: 5, duration: 1500, calories: nil),
            // Older workouts for streak testing
            createSampleWorkout(type: .running, daysAgo: 8, duration: 2200, calories: nil),
            createSampleWorkout(type: .strength, daysAgo: 10, duration: 3300, calories: nil),
            createSampleWorkout(type: .running, daysAgo: 15, duration: 1800, calories: nil)
        ]

        for workout in sampleWorkouts {
            container.mainContext.insert(workout)
        }

        // Use the debug-only method to force premium for preview
        #if DEBUG
        PurchaseManager.shared.forcePremiumForPreview()
        #endif

        return AnalyticsView()
            .modelContainer(container)
    }
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

// MARK: - Card Helper
struct Card<Content: View>: View {
    let accent: Color?
    let content: () -> Content
    init(accent: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.accent = accent
        self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding()
        .background(accent?.opacity(0.08) ?? Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}



// MARK: - Type Breakdown Card
struct TypeBreakdownCard: View {
    let title: String
    let count: Int
    let duration: TimeInterval
    let distance: Double?
    let calories: Double?
    let icon: String
    let color: Color
    init(title: String, count: Int, duration: TimeInterval, distance: Double? = nil, calories: Double? = nil, icon: String, color: Color) {
        self.title = title
        self.count = count
        self.duration = duration
        self.distance = distance
        self.calories = calories
        self.icon = icon
        self.color = color
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            HStack {
                Text("Workouts")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            HStack {
                Text("Duration")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatDuration(duration))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            if let distance = distance, distance > 0 {
                HStack {
                    Text("Distance")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDistance(distance))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            if let calories = calories, calories > 0 {
                HStack {
                    Text("Calories")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(calories))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
} 

// MARK: - Daily Breakdown Row
struct DailyBreakdownRow: View {
    let summary: DailyWorkoutSummary
    let calendar: Calendar
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: summary.date) - 1])
                    .font(.caption.weight(.bold))
                    .foregroundStyle(summary.hasAnyActivity ? .blue : .secondary)
                Circle()
                    .fill(summary.hasAnyActivity ? .blue : .secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .frame(width: 40)
            if summary.hasAnyActivity {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(summary.date, format: .dateTime.day().month(.abbreviated))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatDuration(summary.totalDuration))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    HStack(spacing: 12) {
                        if summary.runningDuration > 0 {
                            Label(formatDistance(summary.runningDistance), systemImage: "figure.run")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        if summary.strengthDuration > 0 {
                            Label(formatDuration(summary.strengthDuration), systemImage: "dumbbell.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                        Spacer()
                    }
                }
            } else {
                HStack {
                    Text(summary.date, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Rest day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            summary.hasAnyActivity ? Color.blue.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
} 