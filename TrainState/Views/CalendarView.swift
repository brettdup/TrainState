import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @GestureState private var dragOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    // Cache frequently used values
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    @State private var cachedDaysInMonth: [Date?] = []
    @State private var cachedWorkoutDates: Set<Date> = []
    @State private var cachedMonthYearString: String = ""
    @State private var cachedWorkoutsForSelectedDate: [Workout] = []
    @State private var cachedWorkoutTypesByDate: [Date: Set<WorkoutType>] = [:]
    
    // Pre-computed grid columns
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern background with depth
                backgroundGradient
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            // Hero section with month selector
                            heroMonthSelector
                                .padding(.top, 20)
                            
                            // Modern calendar grid
                            modernCalendarGrid
                            
                            // Selected date workouts
                            selectedDateSection
                                .padding(.bottom, 20)
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedDate = Date()
                            displayedMonth = calendar.startOfMonth(for: selectedDate)
                        }
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.blue.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .onAppear {
                displayedMonth = calendar.startOfMonth(for: selectedDate)
                updateCachedData()
            }
            .onChange(of: displayedMonth) { _ in
                updateCachedData()
            }
            .onChange(of: workouts) { _ in
                updateCachedWorkoutDates()
                updateCachedWorkoutsForSelectedDate()
                updateCachedWorkoutTypes()
            }
            .onChange(of: selectedDate) { _ in
                updateCachedWorkoutsForSelectedDate()
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            // Base adaptive background
            Color(.systemBackground)
            
            // Layered gradients for depth
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.02),
                    Color.purple.opacity(0.015),
                    Color.cyan.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 100)
            
            // Subtle animated gradient orbs
            RadialGradient(
                colors: [
                    Color.mint.opacity(0.06),
                    Color.mint.opacity(0.02),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 300
            )
            .offset(x: 100, y: -150)
            
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.04),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 250
            )
            .offset(x: -100, y: 150)
        }
    }
    
    // MARK: - Hero Month Selector
    private var heroMonthSelector: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .blue.opacity(0.1), radius: 8, y: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text(cachedMonthYearString)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("\(cachedWorkoutsForSelectedDate.count) workouts")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .blue.opacity(0.1), radius: 8, y: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                nextMonth()
                            }
                        } else if value.translation.width > 50 {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                previousMonth()
                            }
                        }
                    }
            )
        }
    }
    
    // MARK: - Modern Calendar Grid
    private var modernCalendarGrid: some View {
        VStack(spacing: 20) {
            // Days of week header with better typography
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            
            // Calendar days grid with enhanced styling
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(cachedDaysInMonth.indices, id: \.self) { index in
                    if let date = cachedDaysInMonth[index] {
                        ModernDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasWorkouts: cachedWorkoutDates.contains(date),
                            workoutTypes: cachedWorkoutTypesByDate[date] ?? [],
                            workoutCount: workoutsForDate(date).count
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.04), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Selected Date Section
    private var selectedDateSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workouts")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text(selectedDate, style: .date)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !cachedWorkoutsForSelectedDate.isEmpty {
                    Text("\(cachedWorkoutsForSelectedDate.count)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.blue.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 24)
            
            // Workouts list
            if cachedWorkoutsForSelectedDate.isEmpty {
                emptyState
            } else {
                workoutsList
            }
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.04), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private var emptyState: some View {
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
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var workoutsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(cachedWorkoutsForSelectedDate) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    ModernWorkoutCard(workout: workout)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper Methods
    private func workoutsForDate(_ date: Date) -> [Workout] {
        workouts.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }
    
    private func updateCachedData() {
        cachedDaysInMonth = daysInMonth()
        updateCachedWorkoutDates()
        updateCachedMonthYearString()
        updateCachedWorkoutsForSelectedDate()
        updateCachedWorkoutTypes()
    }
    
    private func updateCachedWorkoutDates() {
        cachedWorkoutDates = Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
    }
    
    private func updateCachedWorkoutTypes() {
        var typesByDate: [Date: Set<WorkoutType>] = [:]
        for workout in workouts {
            let date = calendar.startOfDay(for: workout.startDate)
            var types = typesByDate[date] ?? Set<WorkoutType>()
            types.insert(workout.type)
            typesByDate[date] = types
        }
        cachedWorkoutTypesByDate = typesByDate
    }
    
    private func updateCachedMonthYearString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        cachedMonthYearString = formatter.string(from: displayedMonth)
    }
    
    private func updateCachedWorkoutsForSelectedDate() {
        cachedWorkoutsForSelectedDate = workouts.filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
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
    
    private func daysInMonth() -> [Date?] {
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

// MARK: - Modern Day Cell
struct ModernDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkouts: Bool
    let workoutTypes: Set<WorkoutType>
    let workoutCount: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background states
                if isToday {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.3), lineWidth: 2)
                        )
                }
                
                if isSelected {
                    Circle()
                        .fill(.blue)
                        .frame(width: 40, height: 40)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
                
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
            }
            
            // Workout indicators
            if hasWorkouts {
                HStack(spacing: 3) {
                    ForEach(Array(workoutTypes.prefix(3)), id: \.self) { type in
                        Circle()
                            .fill(workoutTypeColor(type))
                            .frame(width: 6, height: 6)
                    }
                    
                    if workoutCount > 3 {
                        Text("+")
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
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
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

// MARK: - Modern Workout Card
struct ModernWorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        HStack(spacing: 16) {
            // Workout type icon
            ZStack {
                Circle()
                    .fill(workoutTypeColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
            }
            
            // Workout details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(workout.type.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(DurationFormatHelper.formatDuration(workout.duration))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(workoutTypeColor)
                }
                
                HStack(spacing: 8) {
                    Text(DateFormatHelper.friendlyTime(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Main category
                    if let categories = workout.categories, let firstCategory = categories.first {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: firstCategory.color) ?? .blue)
                            Text(firstCategory.name)
                                .font(.caption)
                                .foregroundStyle(Color(hex: firstCategory.color) ?? .blue)
                        }
                    }
                    
                    Spacer()
                    
                    // Additional metrics
                    if let distance = workout.distance, workout.type == .running {
                        Text(String(format: "%.1f km", distance / 1000))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.secondary.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: workoutTypeColor.opacity(0.1), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(workoutTypeColor.opacity(0.15), lineWidth: 1)
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
        case .cardio: return "heart.circle.fill"
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

// MARK: - Scroll Offset Preference
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
        configurations: config
    )
    
    CalendarView()
        .modelContainer(container)
} 
