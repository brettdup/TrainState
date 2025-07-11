import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Optimized targeted query - only load what we need
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var allWorkouts: [Workout]
    
    // Performance-focused state
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var optimizedCache = CalendarCache()
    @State private var isInitialized = false
    
    // UI state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    // Constants for better performance
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    // Memoized computed properties
    private var monthString: String {
        optimizedCache.getMonthString(for: displayedMonth)
    }
    
    private var daysInMonth: [Date?] {
        optimizedCache.getDaysInMonth(for: displayedMonth)
    }
    
    private var workoutsForSelectedDate: [Workout] {
        optimizedCache.getWorkouts(for: selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Optimized background
                OptimizedBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 32) {
                        // Hero section
                        OptimizedHeroSection(
                            monthString: monthString,
                            workoutCount: workoutsForSelectedDate.count,
                            onPreviousMonth: previousMonth,
                            onNextMonth: nextMonth,
                            onToday: goToToday
                        )
                        .padding(.top, 20)
                        
                        // Calendar grid
                        OptimizedCalendarGrid(
                            daysInMonth: daysInMonth,
                            selectedDate: selectedDate,
                            cache: optimizedCache,
                            onDateSelected: { date in
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    selectedDate = date
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        )
                        
                        // Selected date workouts
                        OptimizedWorkoutsSection(
                            selectedDate: selectedDate,
                            workouts: workoutsForSelectedDate
                        )
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    OptimizedTodayButton(action: goToToday)
                }
            }
            .task {
                if !isInitialized {
                    await initializeCalendar()
                    isInitialized = true
                }
            }
            .onChange(of: displayedMonth) { _, _ in
                Task { await refreshForMonth() }
            }
        }
    }
    
    // MARK: - Performance Methods
    
    @MainActor
    private func initializeCalendar() async {
        displayedMonth = calendar.startOfMonth(for: selectedDate)
        await optimizedCache.buildCache(workouts: allWorkouts, calendar: calendar)
    }
    
    @MainActor
    private func refreshForMonth() async {
        await optimizedCache.updateForMonth(displayedMonth, workouts: allWorkouts, calendar: calendar)
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func goToToday() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            selectedDate = Date()
            displayedMonth = calendar.startOfMonth(for: selectedDate)
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Optimized Calendar Cache

@Observable
class CalendarCache {
    private var workoutsByDate: [Date: [Workout]] = [:]
    private var workoutTypesByDate: [Date: Set<WorkoutType>] = [:]
    private var monthDaysCache: [String: [Date?]] = [:]
    private var monthStringCache: [Date: String] = [:]
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 600 // 10 minutes
    
    func getWorkouts(for date: Date) -> [Workout] {
        let dayStart = Calendar.current.startOfDay(for: date)
        return workoutsByDate[dayStart] ?? []
    }
    
    func getWorkoutTypes(for date: Date) -> Set<WorkoutType> {
        let dayStart = Calendar.current.startOfDay(for: date)
        return workoutTypesByDate[dayStart] ?? []
    }
    
    func hasWorkouts(for date: Date) -> Bool {
        let dayStart = Calendar.current.startOfDay(for: date)
        return !(workoutsByDate[dayStart]?.isEmpty ?? true)
    }
    
    func getWorkoutCount(for date: Date) -> Int {
        let dayStart = Calendar.current.startOfDay(for: date)
        return workoutsByDate[dayStart]?.count ?? 0
    }
    
    func getDaysInMonth(for date: Date) -> [Date?] {
        let monthKey = monthKeyString(for: date)
        if let cached = monthDaysCache[monthKey] {
            return cached
        }
        
        let days = calculateDaysInMonth(for: date)
        monthDaysCache[monthKey] = days
        return days
    }
    
    func getMonthString(for date: Date) -> String {
        if let cached = monthStringCache[date] {
            return cached
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let string = formatter.string(from: date)
        monthStringCache[date] = string
        return string
    }
    
    func buildCache(workouts: [Workout], calendar: Calendar) async {
        let start = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.buildWorkoutCache(workouts: workouts, calendar: calendar)
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        print("[Performance] Calendar cache build completed in \(String(format: "%.3f", duration))s")
    }
    
    func updateForMonth(_ month: Date, workouts: [Workout], calendar: Calendar) async {
        // Only rebuild if cache is stale
        if Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration {
            return
        }
        
        await buildCache(workouts: workouts, calendar: calendar)
    }
    
    private func buildWorkoutCache(workouts: [Workout], calendar: Calendar) async {
        var tempWorkoutsByDate: [Date: [Workout]] = [:]
        var tempWorkoutTypesByDate: [Date: Set<WorkoutType>] = [:]
        
        // Build cache in single pass - O(n) complexity
        for workout in workouts {
            let dayStart = calendar.startOfDay(for: workout.startDate)
            
            // Group workouts by date
            if tempWorkoutsByDate[dayStart] == nil {
                tempWorkoutsByDate[dayStart] = []
            }
            tempWorkoutsByDate[dayStart]?.append(workout)
            
            // Track workout types by date
            if tempWorkoutTypesByDate[dayStart] == nil {
                tempWorkoutTypesByDate[dayStart] = Set<WorkoutType>()
            }
            tempWorkoutTypesByDate[dayStart]?.insert(workout.type)
        }
        
        // Update cache atomically
        await MainActor.run {
            self.workoutsByDate = tempWorkoutsByDate
            self.workoutTypesByDate = tempWorkoutTypesByDate
            self.lastCacheUpdate = Date()
        }
    }
    
    private func monthKeyString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    private func calculateDaysInMonth(for displayedMonth: Date) -> [Date?] {
        let calendar = Calendar.current
        var days: [Date?] = []
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstOfMonth = calendar.dateInterval(of: .month, for: displayedMonth)?.start else {
            return days
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        
        // Add empty slots for days before the month starts
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days of the month
        let numberOfDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
}

// MARK: - Optimized UI Components

struct OptimizedBackgroundView: View {
    var body: some View {
        // Simplified background for better performance
        Color(.systemBackground)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

struct OptimizedHeroSection: View {
    let monthString: String
    let workoutCount: Int
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onToday: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            OptimizedNavButton(
                icon: "chevron.left",
                action: onPreviousMonth
            )
            
            Spacer()
            
            VStack(spacing: 8) {
                Text(monthString)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("\(workoutCount) workouts")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            OptimizedNavButton(
                icon: "chevron.right",
                action: onNextMonth
            )
        }
        .padding(.horizontal, 20)
    }
}

struct OptimizedNavButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .blue.opacity(0.1), radius: 4, y: 2)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct OptimizedTodayButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.blue.opacity(0.1))
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(minWidth: 80)
    }
}

struct OptimizedCalendarGrid: View {
    let daysInMonth: [Date?]
    let selectedDate: Date
    let cache: CalendarCache
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    var body: some View {
        VStack(spacing: 24) {
            // Days of week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            
            // Calendar days grid
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        OptimizedDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasWorkouts: cache.hasWorkouts(for: date),
                            workoutTypes: cache.getWorkoutTypes(for: date),
                            workoutCount: cache.getWorkoutCount(for: date)
                        )
                        .onTapGesture {
                            onDateSelected(date)
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.quaternary.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct OptimizedDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkouts: Bool
    let workoutTypes: Set<WorkoutType>
    let workoutCount: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background states with improved styling
                if isToday && !isSelected {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.15), .blue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                }
                
                if isSelected {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 17, weight: isToday || isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
            }
            
            // Enhanced workout indicators
            if hasWorkouts {
                HStack(spacing: 3) {
                    ForEach(Array(workoutTypes.prefix(3)), id: \.self) { type in
                        Circle()
                            .fill(workoutTypeColor(type))
                            .frame(width: 5, height: 5)
                            .shadow(color: workoutTypeColor(type).opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    
                    if workoutCount > 3 {
                        Text("+\(workoutCount - 3)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(.quaternary.opacity(0.5))
                            )
                    }
                }
                .frame(height: 8)
            } else {
                Spacer()
                    .frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(.vertical, 6)
    }
    
    private func workoutTypeColor(_ type: WorkoutType) -> Color {
        switch type {
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .yoga: return .purple
        case .strength: return .orange
        case .cardio: return .red
        case .other: return .gray
        }
    }
}

struct OptimizedWorkoutsSection: View {
    let selectedDate: Date
    let workouts: [Workout]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Workouts")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text(selectedDate, style: .date)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !workouts.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Text("\(workouts.count)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.blue.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(.blue.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
            }
            .padding(.horizontal, 24)
            
            // Workouts list
            if workouts.isEmpty {
                OptimizedEmptyState()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(workouts) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            OptimizedWorkoutCard(workout: workout)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.quaternary.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct OptimizedEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.day.timeline.leading")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Workouts")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("No workouts logged for this date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct OptimizedWorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        HStack(spacing: 16) {
            // Simplified workout type icon
            ZStack {
                Circle()
                    .fill(workoutTypeColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
            }
            
            // Workout details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.type.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(DurationFormatHelper.formatDuration(workout.duration))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(workoutTypeColor)
                }
                
                HStack(spacing: 8) {
                    Text(DateFormatHelper.friendlyTime(workout.startDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Simplified category display
                    if let categories = workout.categories, let firstCategory = categories.first {
                        Text(firstCategory.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.secondary.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .padding(.horizontal, 16)
    }
    
    private var workoutTypeColor: Color {
        switch workout.type {
        case .strength: return .purple
        case .cardio: return .red
        case .yoga: return .mint
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .other: return .orange
        }
    }
    
    private var iconName: String {
        switch workout.type {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .other: return "star.fill"
        }
    }
}

// MARK: - Extensions

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

extension DateFormatHelper {
    static func friendlyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    // Create sample workouts for different dates
    let dates = [
        Date(),
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
        Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
        Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    ]
    
    let workoutTypes: [WorkoutType] = [.strength, .running, .cardio, .yoga]
    
    for (index, date) in dates.enumerated() {
        let workout = Workout(
            type: workoutTypes[index % workoutTypes.count],
            startDate: date,
            duration: TimeInterval((30...90).randomElement() ?? 45) * 60,
            calories: Double((200...600).randomElement() ?? 400)
        )
        context.insert(workout)
    }
    
    try? context.save()
    
    return NavigationStack {
        CalendarView()
    }
    .modelContainer(container)
} 
