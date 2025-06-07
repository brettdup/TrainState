import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @GestureState private var dragOffset: CGFloat = 0
    
    // Cache frequently used values
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    @State private var cachedDaysInMonth: [Date?] = []
    @State private var cachedWorkoutDates: Set<Date> = []
    @State private var cachedMonthYearString: String = ""
    @State private var cachedWorkoutsForSelectedDate: [Workout] = []
    @State private var cachedWorkoutTypesByDate: [Date: Set<WorkoutType>] = [:]
    
    // Pre-computed grid columns
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    var body: some View {
        NavigationStack {
            ZStack {
                ColorReflectiveBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        // Month selector with swipe gesture
                        monthSelector
                        
                        // Calendar grid
                        calendarGrid
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .padding(.horizontal)
                        
                        // Workouts for selected date
                        workoutsList
                    }
                    .padding(.vertical)
                    
                }
            }
            .background(Color.clear)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedDate = Date()
                            displayedMonth = calendar.startOfMonth(for: selectedDate)
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        Text("Today")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                    }
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
    
    private var monthSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            Spacer()
            Text(cachedMonthYearString)
                .font(.title2)
                .bold()
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.horizontal, 32)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.spring()) {
                            nextMonth()
                        }
                    } else if value.translation.width > 50 {
                        withAnimation(.spring()) {
                            previousMonth()
                        }
                    }
                }
        )
    }
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Days of week header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Calendar days grid
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(cachedDaysInMonth.indices, id: \.self) { index in
                    if let date = cachedDaysInMonth[index] {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasWorkouts: cachedWorkoutDates.contains(date),
                            workoutTypes: cachedWorkoutTypesByDate[date] ?? []
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
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
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }
    
    private var workoutsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workouts")
                    .font(.title3)
                    .bold()
                Spacer()
                Text(selectedDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if cachedWorkoutsForSelectedDate.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "figure.run",
                    description: Text("No workouts logged for this date")
                )
                .padding(.top, 32)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(cachedWorkoutsForSelectedDate) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            WorkoutCardSD(workout: workout)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
                                )
                                .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
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
        let startOfDay = calendar.startOfDay(for: selectedDate)
        cachedWorkoutsForSelectedDate = workouts.filter { calendar.startOfDay(for: $0.startDate) == startOfDay }
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
    
    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: displayedMonth)!
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offsetDays = firstWeekday - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)!.count
        var days: [Date?] = Array(repeating: nil, count: offsetDays)
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func startOfDay(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day], from: date)
        return self.date(from: components) ?? date
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkouts: Bool
    let workoutTypes: Set<WorkoutType>
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                }
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(isSelected ? .blue : (isToday ? .primary : .primary))
                    .frame(width: 36, height: 36)
            }
            
            if hasWorkouts {
                HStack(spacing: 2) {
                    ForEach(Array(workoutTypes.prefix(3)), id: \.self) { type in
                        Circle()
                            .fill(workoutTypeColor(type))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Spacer().frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(.vertical, 2)
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

#Preview {
    CalendarView()
        .modelContainer(for: Workout.self, inMemory: true)
} 