import SwiftUI
import SwiftData
import UIKit

struct WeeklyView: View {
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var allWorkouts: [Workout]
    @Query private var allCategories: [WorkoutCategory]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate: Date?
    @State private var showingCategorySelection: Workout?
    
    @State private var selectedWeekStart: Date
    
    private let calendar = Calendar.current
    
    init(weekStart: Date = Date()) {
        let startOfWeek = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
        ) ?? weekStart
        let today = Date()
        let todayWeekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) ?? today
        // Clamp initial week to not be in the future
        let clampedStart = min(startOfWeek, todayWeekStart)
        _selectedWeekStart = State(initialValue: clampedStart)
    }
    
    private func weekDays(for weekStart: Date) -> [Date] {
        guard let normalized = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: normalized) }
    }
    
    private var weekRange: String {
        let days = weekDays(for: selectedWeekStart)
        guard let start = days.first, let end = days.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if calendar.isDate(start, equalTo: end, toGranularity: .year) {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end)), \(calendar.component(.year, from: start))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
    
    private func workouts(for date: Date) -> [Workout] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return allWorkouts.filter { workout in
            workout.startDate >= startOfDay && workout.startDate < endOfDay
        }
    }
    
    private var isCurrentWeek: Bool {
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.startOfDay(for: selectedWeekStart)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        
        return today >= weekStart && today < weekEnd
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            // Sectioned list by weekday
            List {
                ForEach(weekDays(for: selectedWeekStart), id: \.self) { date in
                    let dayWorkouts = workouts(for: date)
                    Section(
                        header: WeekdaySectionHeader(
                            date: date,
                            workoutCount: dayWorkouts.count,
                            isToday: calendar.isDateInToday(date)
                        )
                    ) {
                        if dayWorkouts.isEmpty {
                            Text("No workouts")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(dayWorkouts, id: \.id) { workout in
                                WeeklyWorkoutRow(
                                    workout: workout,
                                    onEditCategories: { showingCategorySelection = workout }
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        scrollToToday()
                    } label: {
                        Label("This Week", systemImage: "calendar")
                    }
                    
                    Divider()
                    
                    ForEach(availableWeekStarts, id: \.self) { weekStart in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                selectedWeekStart = weekStart
                                selectedDate = nil
                            }
                        } label: {
                            if calendar.isDate(weekStart, equalTo: selectedWeekStart, toGranularity: .weekOfYear),
                               calendar.isDate(weekStart, equalTo: selectedWeekStart, toGranularity: .yearForWeekOfYear) {
                                Label(weekTitle(for: weekStart), systemImage: "checkmark")
                            } else {
                                Text(weekTitle(for: weekStart))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "calendar.badge.clock")
                }
                .accessibilityLabel(Text("Select week"))
            }
        }
        .sheet(isPresented: Binding(
            get: { showingCategorySelection != nil },
            set: { if !$0 { showingCategorySelection = nil } }
        )) {
            if let workout = showingCategorySelection {
                CategorySelectionSheet(workout: workout)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func previousWeek() {
        if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStart) {
            selectedWeekStart = newWeekStart
        }
    }
    
    private func nextWeek() {
        let today = Date()
        let todayWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) ?? today
        
        if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStart),
           newWeekStart <= todayWeekStart {
            selectedWeekStart = newWeekStart
        }
    }
    
    private func scrollToToday() {
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            selectedWeekStart = startOfWeek
            selectedDate = today
        }
    }
    
    private var availableWeekStarts: [Date] {
        // Weeks from 26 weeks back up to the current week (no future weeks)
        let today = Date()
        let todayWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) ?? today
        
        let weeks = (-26...0).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0, to: todayWeekStart)
        }
        // Newest first in the menu
        return weeks.sorted(by: >)
    }
    
    private func weekTitle(for weekStart: Date) -> String {
        let days = weekDays(for: weekStart)
        guard let start = days.first, let end = days.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let range = "\(f.string(from: start))–\(f.string(from: end))"
        let year = calendar.component(.yearForWeekOfYear, from: start)
        return "\(range), \(year)"
    }
}

// MARK: - Weekday Section Header

struct WeekdaySectionHeader: View {
    let date: Date
    let workoutCount: Int
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    private var weekday: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
    
    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(weekday)
                .font(.headline)
            Text(dateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isToday {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentBlue.opacity(0.15))
                    )
                    .foregroundStyle(AppTheme.accentBlue)
            }
            Spacer()
            if workoutCount > 0 {
                Text("\(workoutCount) \(workoutCount == 1 ? "workout" : "workouts")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Weekly Workout Row

struct WeeklyWorkoutRow: View {
    let workout: Workout
    let onEditCategories: () -> Void
    
    private var workoutTypeColor: Color {
        switch (workout.type) {
        case .strength: return .purple
        case .cardio:   return .red
        case .yoga:     return .mint
        case .running:  return .blue
        case .cycling:  return .green
        case .swimming: return .cyan
        case .other:    return .gray
        }
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    private var durationFormatter: DateComponentsFormatter {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f;
    }
    
    var body: some View {
        NavigationLink {
            WorkoutDetailView(workout: workout)
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: workout.type.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(workoutTypeColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Text(timeFormatter.string(from: workout.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if workout.duration > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(durationFormatter.string(from: workout.duration) ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let categories = workout.categories, !categories.isEmpty {
                        Text(categories.map { $0.name }.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onEditCategories()
            } label: {
                Label("Edit Categories", systemImage: "tag")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onEditCategories()
            } label: {
                Label("Edit Categories", systemImage: "tag")
            }
        }
    }
}

// MARK: - Compact Day Card

private struct CompactDayCard: View {
    let date: Date
    let workouts: [Workout]
    let isSelected: Bool
    let isToday: Bool
    let onAddCategories: (Workout) -> Void
    
    private let calendar = Calendar.current
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var monthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day Header
            HStack(spacing: 16) {
                // Date Circle
                VStack(spacing: 4) {
                    Text(dayNumber)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isToday ? .white : AppTheme.accentBlue)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(isToday ? AppTheme.accentBlue : AppTheme.accentBlue.opacity(0.15))
                        )
                    
                    if isToday {
                        Text("Today")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.accentBlue)
                    }
                }
                
                // Day Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(monthDay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Workout Count
                if !workouts.isEmpty {
                    VStack(spacing: 4) {
                        Text("\(workouts.count)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.accentBlue)
                        Text(workouts.count == 1 ? "workout" : "workouts")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentBlue.opacity(0.1))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? AppTheme.accentBlue.opacity(0.5) : (isToday ? AppTheme.accentBlue.opacity(0.3) : Color(uiColor: .separator).opacity(0.3)),
                                lineWidth: isSelected ? 2 : (isToday ? 1.5 : 1)
                            )
                    )
            )
            
            // Workouts List (if any)
            if !workouts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(workouts, id: \.id) { workout in
                        CompactWorkoutRow(
                            workout: workout,
                            onAddCategories: { onAddCategories(workout) }
                        )
                    }
                }
                .padding(.leading, 66) // Align with day header
            }
        }
    }
}

// MARK: - Compact Workout Row

private struct CompactWorkoutRow: View {
    let workout: Workout
    let onAddCategories: () -> Void
    
    @State private var showingMenu = false
    
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
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    private var durationFormatter: DateComponentsFormatter {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            NavigationLink {
                WorkoutDetailView(workout: workout)
            } label: {
                Image(systemName: workout.type.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(workoutTypeColor.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    Text(workout.type.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 8) {
                    Text(timeFormatter.string(from: workout.startDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if workout.duration > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(durationFormatter.string(from: workout.duration) ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Categories
                HStack(spacing: 4) {
                    if let categories = workout.categories, !categories.isEmpty {
                        ForEach(categories.prefix(2), id: \.id) { category in
                            let color = Color(hex: category.color) ?? .blue
                            Text(category.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(color.opacity(0.15))
                                )
                        }
                        if categories.count > 2 {
                            Text("+\(categories.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                        }
                    }
                    
                    // Add Categories Button
                    Button {
                        onAddCategories()
                    } label: {
                        Image(systemName: workout.categories?.isEmpty ?? true ? "plus.circle.fill" : "tag.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accentBlue)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Day Column (Legacy - kept for reference)

private struct DayColumn: View {
    let date: Date
    let workouts: [Workout]
    let isSelected: Bool
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Day Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text(monthYear)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(dayNumber)
                            .font(.title.weight(.bold))
                            .foregroundStyle(isToday ? .white : AppTheme.accentBlue)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(isToday ? AppTheme.accentBlue : AppTheme.accentBlue.opacity(0.15))
                            )
                        
                        if isToday {
                            Text("Today")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppTheme.accentBlue)
                        }
                    }
                }
                
                // Workout Count Badge
                if !workouts.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accentBlue)
                        Text("\(workouts.count) \(workouts.count == 1 ? "workout" : "workouts")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentBlue.opacity(0.1))
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                isToday ? AppTheme.accentBlue.opacity(0.3) : Color(uiColor: .separator).opacity(0.5),
                                lineWidth: isToday ? 2 : 1
                            )
                    )
            )
            
            // Workouts List
            if workouts.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(workouts, id: \.id) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutCard(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No workouts")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add a workout to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Workout Card

private struct WorkoutCard: View {
    let workout: Workout
    
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
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    private var durationFormatter: DateComponentsFormatter {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(workoutTypeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: workout.type.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.type.rawValue)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Label(timeFormatter.string(from: workout.startDate), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if workout.duration > 0 {
                        Label(durationFormatter.string(from: workout.duration) ?? "", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let categories = workout.categories, !categories.isEmpty {
                    Text(categories.prefix(2).map { $0.name }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    
    // Add sample workouts
    let context = container.mainContext
    let sampleWorkout1 = Workout(
        type: .strength,
        startDate: Date(),
        duration: 3600,
        notes: "Great workout!"
    )
    let sampleWorkout2 = Workout(
        type: .running,
        startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
        duration: 1800,
        distance: 5000
    )
    context.insert(sampleWorkout1)
    context.insert(sampleWorkout2)
    
    return WeeklyView()
        .modelContainer(container)
}

// MARK: - Category Selection Sheet

struct CategorySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let workout: Workout
    
    @Query private var allCategories: [WorkoutCategory]
    @Query private var allSubcategories: [WorkoutSubcategory]
    
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select categories for this workout")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Categories") {
                    ForEach(filteredCategories) { category in
                        Button {
                            toggleCategory(category)
                        } label: {
                            HStack {
                                Image(systemName: selectedCategories.contains(where: { $0.id == category.id }) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Color(hex: category.color) ?? .blue)
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if !selectedCategories.isEmpty {
                    Section("Selected") {
                        ForEach(selectedCategories, id: \.id) { category in
                            HStack {
                                CategoryChip(category: category)
                                Spacer()
                                Button("Remove") {
                                    toggleCategory(category)
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveCategories()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedCategories = workout.categories ?? []
                selectedSubcategories = workout.subcategories ?? []
            }
        }
    }
    
    private var filteredCategories: [WorkoutCategory] {
        allCategories.filter { $0.workoutType == workout.type }
    }
    
    private func toggleCategory(_ category: WorkoutCategory) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
            // Remove subcategories when category is removed
            selectedSubcategories.removeAll { $0.category?.id == category.id }
        } else {
            selectedCategories.append(category)
        }
    }
    
    private func saveCategories() {
        // De-dupe by id to avoid accidental duplicates
        var seen = Set<UUID>()
        let uniqueCategories = selectedCategories.filter { seen.insert($0.id).inserted }
        workout.categories = uniqueCategories.isEmpty ? nil : uniqueCategories
        workout.subcategories = selectedSubcategories.isEmpty ? nil : selectedSubcategories
        try? modelContext.save()
    }
}

