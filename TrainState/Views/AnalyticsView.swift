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
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedWeekDisplayMode: WeekDisplayMode = .lastSevenDays
    @State private var showingPremiumPaywall = false
    @State private var animateCards = false
    
    // Performance optimized data management
    @State private var cachedData: AnalyticsCachedData?
    @State private var lastUpdateTime: Date = Date()
    @State private var isLoadingData = false
    private let calendar = Calendar.current
    
    // Computed properties for date range
    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch selectedWeekDisplayMode {
        case .lastSevenDays:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return (sevenDaysAgo, tomorrow)
        case .calendarWeek:
            // Always use Monday as the start of the week
            let weekday = calendar.component(.weekday, from: startOfToday)
            // In the Gregorian calendar: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
            // To get the most recent Monday:
            let daysSinceMonday = (weekday + 5) % 7 // 0 if Monday, 1 if Tuesday, ..., 6 if Sunday
            let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfToday)!
            let nextMonday = calendar.date(byAdding: .day, value: 7, to: thisMonday)!
            return (thisMonday, nextMonday)
        }
    }
    
    // Optimized query that only fetches workouts within the date range
    @Query private var allWorkouts: [Workout]
    
    init() {
        // Initialize with a broad predicate that will be refined in the view
        // Fetch last 60 days to ensure we have enough data for streak calculations
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: startOfToday)!
        
        _allWorkouts = Query(
            filter: #Predicate<Workout> { workout in
                workout.startDate >= sixtyDaysAgo
            },
            sort: [SortDescriptor(\Workout.startDate, order: .reverse)]
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Modern time period selector
                        ModernTimePeriodSelector(
                            selectedMode: $selectedWeekDisplayMode,
                            isPremium: purchaseManager.hasActiveSubscription
                        )
                        .padding(.horizontal, 20)
                        .scaleEffect(animateCards ? 1 : 0.95)
                        .opacity(animateCards ? 1 : 0)
                        
                        if purchaseManager.hasActiveSubscription {
                            // Premium Content with modern design
                            Group {
                                if isLoadingData && cachedData == nil {
                                    // Loading state
                                    VStack(spacing: 20) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .tint(.blue)
                                        
                                        Text("Loading analytics...")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 200)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                                } else {
                                    // Hero stats overview
                                    HeroStatsView(
                                        filteredWorkouts: cachedData?.filteredWorkouts ?? (running: [], strength: []),
                                        currentStreak: cachedData?.currentStreak ?? 0,
                                        longestStreak: cachedData?.longestStreak ?? 0
                                    )
                                    .scaleEffect(animateCards ? 1 : 0.95)
                                    .opacity(animateCards ? 1 : 0)
                                    
                                    // Enhanced activity chart
                                    ModernActivityChartView(dailySummaries: cachedData?.dailySummaries ?? [])
                                        .scaleEffect(animateCards ? 1 : 0.95)
                                        .opacity(animateCards ? 1 : 0)
                                    
                                    // Modern weekly breakdown
                                    ModernWeeklyBreakdownView(
                                        dailySummaries: cachedData?.dailySummaries ?? [],
                                        calendar: calendar
                                    )
                                    .scaleEffect(animateCards ? 1 : 0.95)
                                        .opacity(animateCards ? 1 : 0)
                                    
                                    // Quick access features
                                    QuickAccessFeaturesView()
                                        .scaleEffect(animateCards ? 1 : 0.95)
                                        .opacity(animateCards ? 1 : 0)
                                }
                            }
                        } else {
                            // Enhanced free content with premium preview
                            Group {
                                // Basic stats overview
                                BasicStatsOverview(filteredWorkouts: cachedData?.filteredWorkouts ?? (running: [], strength: []))
                                    .scaleEffect(animateCards ? 1 : 0.95)
                                    .opacity(animateCards ? 1 : 0)
                                
                                // Enhanced premium upsell
                                ModernPremiumUpsellCard(showingPremiumPaywall: $showingPremiumPaywall)
                                    .scaleEffect(animateCards ? 1 : 0.95)
                                    .opacity(animateCards ? 1 : 0)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .navigationTitle("Analytics")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.clear, for: .navigationBar)
                .background(.clear)
            }
        }
        .onAppear {
            updateCachedDataIfNeeded()
            animateCards = true
        }
        .onChange(of: allWorkouts) { _, _ in
            updateCachedDataIfNeeded()
        }
        .onChange(of: selectedWeekDisplayMode) { _, _ in
            updateCachedDataIfNeeded()
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
    
    // MARK: - Optimized Data Processing
    private func updateCachedDataIfNeeded() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // Only update if enough time has passed or if we don't have cached data
        guard cachedData == nil || timeSinceLastUpdate > 1.0 else { return }
        
        lastUpdateTime = now
        isLoadingData = true
        
        // Perform data processing on background queue
        Task {
            let newCachedData = await processAnalyticsData()
            
            // Update UI on main queue
            await MainActor.run {
                cachedData = newCachedData
                isLoadingData = false
            }
        }
    }
    
    @MainActor
    private func processAnalyticsData() async -> AnalyticsCachedData {
        let range = dateRange
        
        // Filter workouts for the current date range
        let filtered = allWorkouts.filter { $0.startDate >= range.start && $0.startDate < range.end }
        let running = filtered.filter { $0.type == .running }
        let strength = filtered.filter { $0.type == .strength }
        
        // Calculate daily summaries efficiently
        let dailySummaries = await calculateDailySummaries(
            running: running,
            strength: strength,
            dateRange: range
        )
        
        // Calculate streaks efficiently
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
            let strengthCalories = strengthWorkouts.compactMap { $0.calories }.reduce(0, +)
            
            summaries.append(DailyWorkoutSummary(
                date: dayStart,
                runningDuration: runningDuration,
                runningDistance: runningDistance,
                strengthDuration: strengthDuration,
                strengthCalories: strengthCalories
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

// MARK: - Modern Supporting Views

struct ModernTimePeriodSelector: View {
    @Binding var selectedMode: WeekDisplayMode
    let isPremium: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Time Period")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if !isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text("Premium")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
            }
            
            Picker("Week Display", selection: $selectedMode) {
                ForEach(WeekDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!isPremium)
            .opacity(isPremium ? 1.0 : 0.6)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct HeroStatsView: View {
    let filteredWorkouts: (running: [Workout], strength: [Workout])
    let currentStreak: Int
    let longestStreak: Int
    
    var body: some View {
        VStack(spacing: 20) {
            // Hero numbers
            HStack(spacing: 16) {
                HeroStatCard(
                    title: "Total Workouts",
                    value: "\(filteredWorkouts.running.count + filteredWorkouts.strength.count)",
                    icon: "figure.run",
                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    valueColor: .blue,
                    iconColor: .blue,
                    titleColor: .primary,
                    subtitleColor: .secondary
                )
                
                HeroStatCard(
                    title: "Current Streak",
                    value: "\(currentStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    gradient: LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                    valueColor: .orange,
                    iconColor: .orange,
                    titleColor: .primary,
                    subtitleColor: .secondary
                )
            }
            
            // Workout type breakdown
            HStack(spacing: 16) {
                AnalyticsWorkoutTypeCard(
                    title: "Running",
                    workouts: filteredWorkouts.running,
                    color: .blue,
                    icon: "figure.run"
                )
                
                AnalyticsWorkoutTypeCard(
                    title: "Strength",
                    workouts: filteredWorkouts.strength,
                    color: .purple,
                    icon: "dumbbell.fill"
                )
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct HeroStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let gradient: LinearGradient
    
    // New: Allow custom text/icon color for each card
    let valueColor: Color?
    let iconColor: Color?
    let titleColor: Color?
    let subtitleColor: Color?
    
    init(title: String, value: String, subtitle: String? = nil, icon: String, gradient: LinearGradient, valueColor: Color? = nil, iconColor: Color? = nil, titleColor: Color? = nil, subtitleColor: Color? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
        self.valueColor = valueColor
        self.iconColor = iconColor
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 50, height: 50)
                    .blur(radius: 10)
                    .opacity(0.6)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor ?? .white)
                    .shadow(color: (iconColor ?? .white).opacity(0.8), radius: 6)
            }
            
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(valueColor ?? .white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(subtitleColor ?? .white.opacity(0.7))
                    }
                }
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(titleColor ?? .white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct AnalyticsWorkoutTypeCard: View {
    let title: String
    let workouts: [Workout]
    let color: Color
    let icon: String
    
    // Computed properties to avoid recalculating on every render
    private var totalDuration: TimeInterval {
        workouts.reduce(0) { $0 + $1.duration }
    }
    
    private var totalDistance: Double {
        workouts.compactMap { $0.distance }.reduce(0, +)
    }
    
    private var totalCalories: Double {
        workouts.compactMap { $0.calories }.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Workouts")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(workouts.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                
                HStack {
                    Text("Duration")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(formatDuration(totalDuration))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                
                if title == "Running" {
                    if totalDistance > 0 {
                        HStack {
                            Text("Distance")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(formatDistance(totalDistance))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                } else {
                    if totalCalories > 0 {
                        HStack {
                            Text("Calories")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(totalCalories))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ModernActivityChartView: View {
    let dailySummaries: [DailyWorkoutSummary]
    
    // Computed property to avoid recalculating on every render
    private var activeDaysCount: Int {
        dailySummaries.filter { $0.hasAnyActivity }.count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Overview")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("Weekly workout duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(activeDaysCount)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                    
                    Text("active days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            // Enhanced chart with optimized rendering
            Chart {
                ForEach(dailySummaries) { summary in
                    BarMark(
                        x: .value("Date", summary.date, unit: .day),
                        y: .value("Duration", summary.totalDuration / 60)
                    )
                    .foregroundStyle(
                        summary.hasAnyActivity ? 
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
            }
            .frame(height: 180)
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
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ModernWeeklyBreakdownView: View {
    let dailySummaries: [DailyWorkoutSummary]
    let calendar: Calendar
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Daily Breakdown")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            LazyVStack(spacing: 12) {
                ForEach(dailySummaries) { summary in
                    ModernDailyRow(summary: summary, calendar: calendar)
                        .id(summary.date) // Ensure proper identification for LazyVStack
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ModernDailyRow: View {
    let summary: DailyWorkoutSummary
    let calendar: Calendar
    
    var body: some View {
        HStack(spacing: 16) {
            // Date indicator
            VStack(spacing: 4) {
                Text(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: summary.date) - 1])
                    .font(.caption.weight(.bold))
                    .foregroundStyle(summary.hasAnyActivity ? .blue : .secondary)
                
                Circle()
                    .fill(summary.hasAnyActivity ? .blue : .secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .frame(width: 40)
            
            // Content
            if summary.hasAnyActivity {
                VStack(spacing: 8) {
                    HStack {
                        Text(summary.date, format: .dateTime.day().month(.abbreviated))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(formatDuration(summary.totalDuration))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    
                    if summary.runningDuration > 0 || summary.strengthDuration > 0 {
                        HStack(spacing: 12) {
                            if summary.runningDuration > 0 {
                                CompactActivityIndicator(
                                    icon: "figure.run",
                                    value: formatDistance(summary.runningDistance),
                                    color: .blue
                                )
                            }
                            
                            if summary.strengthDuration > 0 {
                                CompactActivityIndicator(
                                    icon: "dumbbell.fill",
                                    value: "\(Int(summary.strengthCalories))cal",
                                    color: .purple
                                )
                            }
                            
                            Spacer()
                        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            summary.hasAnyActivity ?
            Color.blue.opacity(0.06) :
            Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    summary.hasAnyActivity ?
                    Color.blue.opacity(0.1) :
                    Color.clear,
                    lineWidth: 1
                )
        )
    }
}

struct CompactActivityIndicator: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }
}

struct QuickAccessFeaturesView: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Access")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                NavigationLink {
                    SubcategoryLastLoggedView()
                } label: {
                    QuickAccessCard(
                        icon: "clock.fill",
                        title: "Last Logged",
                        subtitle: "Exercise tracking",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
                
                QuickAccessCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Insights",
                    subtitle: "Coming soon",
                    color: .purple
                )
                .opacity(0.6)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct QuickAccessCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct BasicStatsOverview: View {
    let filteredWorkouts: (running: [Workout], strength: [Workout])
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("This Week")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(filteredWorkouts.running.count + filteredWorkouts.strength.count) workouts")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 16) {
                BasicStatCard(
                    title: "Running",
                    count: filteredWorkouts.running.count,
                    icon: "figure.run",
                    color: .blue
                )
                
                BasicStatCard(
                    title: "Strength",
                    count: filteredWorkouts.strength.count,
                    icon: "dumbbell.fill",
                    color: .purple
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct BasicStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ModernPremiumUpsellCard: View {
    @Binding var showingPremiumPaywall: Bool
    @State private var animateGradient = false
    
    var body: some View {
        Button(action: { showingPremiumPaywall = true }) {
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.blue, .purple, .pink, .orange, .blue],
                                center: .center
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                        .opacity(0.6)
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.8), radius: 8)
                }
                
                VStack(spacing: 12) {
                    Text("Unlock Advanced Analytics")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Get detailed insights with interactive charts, activity streaks, daily breakdowns, and much more")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                
                // Feature highlights
                VStack(spacing: 12) {
                    FeatureHighlight(icon: "chart.bar.fill", text: "Interactive Charts & Graphs")
                    FeatureHighlight(icon: "flame.fill", text: "Activity Streaks & Goals")
                    FeatureHighlight(icon: "calendar.badge.clock", text: "Detailed Daily Breakdowns")
                }
                
                // CTA Button
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.headline)
                    
                    Text("Upgrade to Premium")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.white, in: Capsule())
            }
            .padding(32)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .purple.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .onAppear {
            animateGradient = true
        }
    }
}

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