import SwiftUI
import SwiftData

enum CalendarViewMode: String, CaseIterable {
    case month = "Month"
    case week = "Week"
    
    var icon: String {
        switch self {
        case .month: return "calendar"
        case .week: return "calendar.day.timeline.leading"
        }
    }
}

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Optimized targeted query - only load what we need
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var allWorkouts: [Workout]
    
    // Performance-focused state
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var optimizedCache = CalendarCache()
    @State private var isInitialized = false
    
    // Enhanced UI state
    @State private var viewMode: CalendarViewMode = .month
    @State private var selectedWorkoutTypes: Set<WorkoutType> = Set(WorkoutType.allCases)
    @State private var showingFilters = false
    @State private var showingDatePicker = false
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
        // Always use direct filtering for reliability
        let workouts = allWorkouts.filter { workout in
            calendar.isDate(workout.startDate, inSameDayAs: selectedDate) &&
            selectedWorkoutTypes.contains(workout.type)
        }
        return workouts
    }
    
    private var filteredWorkoutCount: Int {
        workoutsForSelectedDate.count
    }
    
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        var dates: [Date] = []
        var currentDate = weekInterval.start
        
        for _ in 0..<7 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return dates
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                        // Enhanced hero section with view mode toggle
                        EnhancedHeroSection(
                            monthString: monthString,
                            workoutCount: filteredWorkoutCount,
                            viewMode: $viewMode,
                            onPreviousMonth: previousMonth,
                            onNextMonth: nextMonth,
                            onToday: goToToday,
                            onDatePickerTap: { showingDatePicker = true }
                        )
                        .padding(.top, 16)
                        
                        // View mode content
                        if viewMode == .month {
                            // Enhanced calendar grid
                            EnhancedCalendarGrid(
                                daysInMonth: daysInMonth,
                                selectedDate: selectedDate,
                                cache: optimizedCache,
                                allWorkouts: allWorkouts,
                                selectedWorkoutTypes: selectedWorkoutTypes,
                                onDateSelected: { date in
                                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                        selectedDate = date
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            )
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        // Only respond to horizontal swipes that are more horizontal than vertical
                                        if abs(value.translation.width) > abs(value.translation.height) && abs(value.translation.width) > 100 {
                                            if value.translation.width > 100 {
                                                previousMonth()
                                            } else if value.translation.width < -100 {
                                                nextMonth()
                                            }
                                        }
                                    }
                            )
                        } else {
                            // Week view
                            EnhancedWeekView(
                                weekDates: weekDates,
                                selectedDate: selectedDate,
                                cache: optimizedCache,
                                allWorkouts: allWorkouts,
                                selectedWorkoutTypes: selectedWorkoutTypes,
                                onDateSelected: { date in
                                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                        selectedDate = date
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            )
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        // Only respond to horizontal swipes that are more horizontal than vertical
                                        if abs(value.translation.width) > abs(value.translation.height) && abs(value.translation.width) > 100 {
                                            if value.translation.width > 100 {
                                                previousWeek()
                                            } else if value.translation.width < -100 {
                                                nextWeek()
                                            }
                                        }
                                    }
                            )
                        }
                        
                        // Enhanced workouts section
                        EnhancedWorkoutsSection(
                            selectedDate: selectedDate,
                            workouts: workoutsForSelectedDate,
                            selectedWorkoutTypes: selectedWorkoutTypes
                        )
                        .padding(.bottom, 100)
                }
            }
            .background(
                EnhancedBackgroundView()
                    .ignoresSafeArea()
            )
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    OptimizedTodayButton(action: goToToday)
                }
            }
            .task {
                if !isInitialized {
                    await initializeCalendar()
                    updateCache()
                    isInitialized = true
                }
            }
            .onChange(of: displayedMonth) { _, _ in
                Task { await refreshForMonth() }
            }
            .onChange(of: allWorkouts.count) { _, _ in
                updateCache()
            }
            .sheet(isPresented: $showingFilters) {
                WorkoutTypeFilterSheet(
                    selectedTypes: $selectedWorkoutTypes,
                    isPresented: $showingFilters
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: $displayedMonth,
                    isPresented: $showingDatePicker
                )
            }
        }
    }
    
    // MARK: - Performance Methods
    
    private func updateCache() {
        Task {
            await optimizedCache.buildCache(workouts: allWorkouts, calendar: calendar)
        }
    }
    
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
    
    private func previousWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
            selectedDate = newDate
            displayedMonth = calendar.startOfMonth(for: selectedDate)
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func nextWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
            selectedDate = newDate
            displayedMonth = calendar.startOfMonth(for: selectedDate)
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
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

// MARK: - Enhanced UI Components

struct EnhancedBackgroundView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground),
                Color(.systemGray6).opacity(0.4),
                Color(.systemBackground)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle animated overlay
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.05),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
        )
    }
}

struct EnhancedHeroSection: View {
    let monthString: String
    let workoutCount: Int
    @Binding var viewMode: CalendarViewMode
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onToday: () -> Void
    let onDatePickerTap: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Month navigation and title
            HStack(spacing: 20) {
                OptimizedNavButton(
                    icon: "chevron.left",
                    action: onPreviousMonth
                )
                
                Spacer()
                
                Button(action: onDatePickerTap) {
                    VStack(spacing: 6) {
                        Text(monthString)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("\(workoutCount) workouts")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                OptimizedNavButton(
                    icon: "chevron.right",
                    action: onNextMonth
                )
            }
            
            // View mode toggle
            HStack(spacing: 8) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                            viewMode = mode
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(mode.rawValue)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(viewMode == mode ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewMode == mode ? .blue : .blue.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
}

struct EnhancedCalendarGrid: View {
    let daysInMonth: [Date?]
    let selectedDate: Date
    let cache: CalendarCache
    let allWorkouts: [Workout]
    let selectedWorkoutTypes: Set<WorkoutType>
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        VStack(spacing: 12) {
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
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        EnhancedDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasWorkouts: hasFilteredWorkouts(for: date),
                            workoutTypes: getFilteredWorkoutTypes(for: date),
                            workoutCount: getFilteredWorkoutCount(for: date)
                        )
                        .onTapGesture {
                            onDateSelected(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
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
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private func hasFilteredWorkouts(for date: Date) -> Bool {
        !getWorkoutsForDate(date).isEmpty
    }
    
    private func getFilteredWorkoutTypes(for date: Date) -> Set<WorkoutType> {
        Set(getWorkoutsForDate(date).map { $0.type })
    }
    
    private func getFilteredWorkoutCount(for date: Date) -> Int {
        getWorkoutsForDate(date).count
    }
    
    private func getWorkoutsForDate(_ date: Date) -> [Workout] {
        // Try cache first, fallback to direct filtering
        let cachedWorkouts = cache.getWorkouts(for: date)
        if !cachedWorkouts.isEmpty {
            return cachedWorkouts.filter { selectedWorkoutTypes.contains($0.type) }
        }
        
        // Fallback to direct filtering from allWorkouts
        return allWorkouts.filter { workout in
            calendar.isDate(workout.startDate, inSameDayAs: date) &&
            selectedWorkoutTypes.contains(workout.type)
        }
    }
}

struct EnhancedDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkouts: Bool
    let workoutTypes: Set<WorkoutType>
    let workoutCount: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Enhanced background states
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.blue.opacity(0.4), lineWidth: 2)
                        )
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                
                if !isSelected && !isToday && hasWorkouts {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.quaternary.opacity(0.3))
                        .frame(width: 48, height: 48)
                }
                
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, weight: isToday || isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
            }
            
            // Enhanced workout indicators
            if hasWorkouts {
                HStack(spacing: 2) {
                    ForEach(Array(workoutTypes.prefix(3)), id: \.self) { type in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(workoutTypeColor(type))
                            .frame(width: 6, height: 6)
                            .shadow(color: workoutTypeColor(type).opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    
                    if workoutCount > 3 {
                        Text("•")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 8)
            } else {
                Spacer()
                    .frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 44)
        .padding(.vertical, 4)
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

struct EnhancedWeekView: View {
    let weekDates: [Date]
    let selectedDate: Date
    let cache: CalendarCache
    let allWorkouts: [Workout]
    let selectedWorkoutTypes: Set<WorkoutType>
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Week view header
            HStack(spacing: 0) {
                ForEach(Array(zip(daysOfWeek, weekDates)), id: \.1) { dayName, date in
                    VStack(spacing: 12) {
                        Text(dayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        
                        Button(action: { onDateSelected(date) }) {
                            EnhancedWeekDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                workouts: getWorkoutsForDate(date)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
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
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private func getWorkoutsForDate(_ date: Date) -> [Workout] {
        // Try cache first, fallback to direct filtering
        let cachedWorkouts = cache.getWorkouts(for: date)
        if !cachedWorkouts.isEmpty {
            return cachedWorkouts.filter { selectedWorkoutTypes.contains($0.type) }
        }
        
        // Fallback to direct filtering from allWorkouts
        return allWorkouts.filter { workout in
            calendar.isDate(workout.startDate, inSameDayAs: date) &&
            selectedWorkoutTypes.contains(workout.type)
        }
    }
}

struct EnhancedWeekDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let workouts: [Workout]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isToday && !isSelected {
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.4), lineWidth: 2)
                        )
                }
                
                if isSelected {
                    Circle()
                        .fill(.blue)
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, weight: isToday || isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
            }
            
            // Workout count indicator
            if !workouts.isEmpty {
                Text("\(workouts.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(.blue)
                    )
            }
        }
    }
}

struct EnhancedWorkoutsSection: View {
    let selectedDate: Date
    let workouts: [Workout]
    let selectedWorkoutTypes: Set<WorkoutType>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Enhanced section header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workouts")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Text(selectedDate, style: .date)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        if selectedWorkoutTypes.count < WorkoutType.allCases.count {
                            Text("• Filtered")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer()
                
                if !workouts.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(workouts.count)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.blue)
                        
                        Text("workouts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Enhanced workouts list
            if workouts.isEmpty {
                EnhancedEmptyState(hasFilters: selectedWorkoutTypes.count < WorkoutType.allCases.count)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(workouts) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            EnhancedWorkoutCard(workout: workout)
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
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct EnhancedEmptyState: View {
    let hasFilters: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle" : "calendar.day.timeline.leading")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(hasFilters ? "No Filtered Workouts" : "No Workouts")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(hasFilters ? "Try adjusting your filters" : "No workouts logged for this date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct EnhancedWorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced workout type icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [workoutTypeColor.opacity(0.2), workoutTypeColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
            }
            
            // Enhanced workout details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(workout.type.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(DurationFormatHelper.formatDuration(workout.duration))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(workoutTypeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(workoutTypeColor.opacity(0.1))
                        )
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(DateFormatHelper.friendlyTime(workout.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let categories = workout.categories, let firstCategory = categories.first {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(firstCategory.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.secondary.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.quaternary.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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

// Filter and Date Picker Sheets
struct WorkoutTypeFilterSheet: View {
    @Binding var selectedTypes: Set<WorkoutType>
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: iconForType(type))
                            .foregroundColor(colorForType(type))
                            .frame(width: 24)
                        
                        Text(type.rawValue)
                            .font(.body)
                        
                        Spacer()
                        
                        if selectedTypes.contains(type) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedTypes = Set(WorkoutType.allCases)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func iconForType(_ type: WorkoutType) -> String {
        switch type {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .other: return "star.fill"
        }
    }
    
    private func colorForType(_ type: WorkoutType) -> Color {
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

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Legacy Optimized UI Components

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
                            .frame(height: 44)
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
