import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workouts: [Workout] = []
    @State private var selectedWeekStart: Date = Calendar.current.startOfWeek(for: Date())
    @State private var weekPickerDate: Date = Date()
    @State private var showingWeekPicker = false
    @State private var displayMode: CalendarDisplayMode = .week

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        weekNavigatorCard
                        displayModePicker
                        weekStripCard
                        weekSummaryCard
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                ForEach(displayedDays, id: \.self) { day in
                    daySection(for: day)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingWeekPicker) {
                weekPickerSheet
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            loadDisplayedWorkouts()
        }
        .onChange(of: selectedWeekStart) { _, _ in
            loadDisplayedWorkouts()
        }
        .onChange(of: displayMode) { _, _ in
            loadDisplayedWorkouts()
        }
    }

    private func daySection(for day: Date) -> some View {
        let dayWorkouts = workoutsForDay(day)

        return Section {
            if dayWorkouts.isEmpty {
                restDayRow
            } else {
                ForEach(dayWorkouts, id: \.id) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRowView(workout: workout, showsChevron: false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            daySectionHeader(for: day, workouts: dayWorkouts)
        }
    }

    private func daySectionHeader(for day: Date, workouts: [Workout]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sectionHeaderTitle(for: day))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(daySubtitle(for: workouts))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(dayNumberText(for: day))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : Color.secondary)
        }
        .textCase(nil)
    }

    private var restDayRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: ViewConstants.cardCornerRadius)
                        .fill(ThemeColor.primaryUi03())
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("No workouts logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekNavigatorCard: some View {
        HStack(spacing: 12) {
            Button {
                moveDisplayedWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ThemeColor.primaryUi03())
                    )
            }
            .buttonStyle(.plain)
            .disabled(displayMode == .last7Days)
            .opacity(displayMode == .last7Days ? 0.45 : 1)

            Button {
                weekPickerDate = selectedWeekStart
                if displayMode == .week {
                    showingWeekPicker = true
                }
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 5) {
                        Text(displayedRangeText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .allowsTightening(true)

                        Image(systemName: "calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Text(displayedRangeSubtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .disabled(displayMode == .last7Days)

            Button {
                moveDisplayedWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ThemeColor.primaryUi03())
                    )
            }
            .buttonStyle(.plain)
            .disabled(displayMode == .last7Days || selectedWeekStart >= Calendar.current.startOfWeek(for: Date()))
            .opacity(displayMode == .last7Days ? 0.45 : 1)

            Button {
                selectedWeekStart = Calendar.current.startOfWeek(for: Date())
                displayMode = .week
            } label: {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ThemeColor.primaryUi03())
                    )
            }
            .buttonStyle(.plain)
            .opacity(displayMode == .week && isShowingCurrentWeek ? 0.5 : 1)
            .disabled(displayMode == .week && isShowingCurrentWeek)
        }
        .padding(12)
        .glassCard()
    }

    private var displayModePicker: some View {
        Picker("Calendar range", selection: $displayMode) {
            ForEach(CalendarDisplayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(16)
        .glassCard()
    }

    private var weekPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker(
                    "Week",
                    selection: $weekPickerDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .onChange(of: weekPickerDate) { _, newValue in
                    selectedWeekStart = Calendar.current.startOfWeek(for: newValue)
                }
            }
            .padding(20)
            .navigationTitle("Choose Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        weekPickerDate = Date()
                        selectedWeekStart = Calendar.current.startOfWeek(for: Date())
                    } label: {
                        Label("This Week", systemImage: "calendar.badge.clock")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingWeekPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var weekStripCard: some View {
        HStack(spacing: 8) {
            ForEach(displayedDays, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let dayWorkouts = workoutsForDay(day)

                VStack(spacing: 7) {
                    Text(shortWeekdayText(for: day))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(dayNumberText(for: day))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(isToday ? Color.white : Color.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isToday ? Color.accentColor : Color.clear)
                        )

                    HStack(spacing: 2) {
                        ForEach(Array(dayWorkoutTypes(for: dayWorkouts).prefix(3)), id: \.self) { type in
                            Circle()
                                .fill(type.tintColor)
                                .frame(width: 5, height: 5)
                        }

                        if dayWorkouts.isEmpty {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: ViewConstants.cardCornerRadius)
                        .fill(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                )
            }
        }
        .padding(10)
        .glassCard(prominence: .regular)
    }

    private var weekSummaryCard: some View {
        let summary = weekSummary(for: workoutsInDisplayedPeriod)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 24) {
                SummaryStat(value: "\(summary.count)", label: "Workouts")
                Divider()
                    .frame(height: 32)
                SummaryStat(value: summary.duration, label: "Duration")
                if summary.distance > 0 {
                    Divider()
                        .frame(height: 32)
                    SummaryStat(value: String(format: "%.1f km", summary.distance), label: "Distance")
                }
            }

            categorySummaryChips
        }
        .padding(16)
        .glassCard()
    }

    private var categorySummaryChips: some View {
        let categories = trainedCategorySummaries(for: workoutsInDisplayedPeriod)

        return Group {
            if categories.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.id) { category in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text(category.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(category.count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(category.color.opacity(0.10))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(category.color.opacity(0.18), lineWidth: 0.75)
                            )
                        }
                    }
                }
            }
        }
    }

    private var isShowingCurrentWeek: Bool {
        Calendar.current.isDate(selectedWeekStart, equalTo: Calendar.current.startOfWeek(for: Date()), toGranularity: .weekOfYear)
    }

    private var workoutsInDisplayedWeek: [Workout] {
        workouts
    }

    private var workoutsInDisplayedPeriod: [Workout] {
        switch displayMode {
        case .week:
            return workouts
        case .last7Days:
            return workouts
        }
    }

    private func loadDisplayedWorkouts() {
        guard let interval = displayedDateInterval else {
            workouts = []
            return
        }

        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.startDate >= start && workout.startDate < end
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        workouts = (try? modelContext.fetch(descriptor)) ?? []
    }

    private var displayedDateInterval: DateInterval? {
        let calendar = Calendar.current
        switch displayMode {
        case .week:
            guard let end = calendar.date(byAdding: .day, value: 7, to: selectedWeekStart) else {
                return nil
            }
            return DateInterval(start: selectedWeekStart, end: end)
        case .last7Days:
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -6, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: today) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }
    }

    private var displayedDays: [Date] {
        switch displayMode {
        case .week:
            return weekDays
        case .last7Days:
            let today = Calendar.current.startOfDay(for: Date())
            return (0..<7)
                .compactMap { Calendar.current.date(byAdding: .day, value: -6 + $0, to: today) }
        }
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedWeekStart) }
    }

    private var displayedRangeText: String {
        switch displayMode {
        case .week:
            return weekRangeText(for: selectedWeekStart)
        case .last7Days:
            guard let start = displayedDays.first else { return "Last 7 days" }
            return rangeText(from: start, dayCount: 7)
        }
    }

    private var displayedRangeSubtitle: String {
        switch displayMode {
        case .week:
            return isShowingCurrentWeek ? "Current week" : "Viewing past week"
        case .last7Days:
            return "Last 7 days"
        }
    }

    private func moveDisplayedWeek(by weekOffset: Int) {
        let candidate = Calendar.current.date(byAdding: .day, value: weekOffset * 7, to: selectedWeekStart) ?? selectedWeekStart
        let currentWeekStart = Calendar.current.startOfWeek(for: Date())
        selectedWeekStart = min(candidate, currentWeekStart)
    }

    private func weekSummary(for workouts: [Workout]) -> (count: Int, duration: String, distance: Double) {
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let totalDistance = workouts.compactMap(\.distance).reduce(0, +)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        let durationText = formatter.string(from: totalDuration) ?? "0m"
        return (workouts.count, durationText, totalDistance)
    }

    private func sectionHeaderTitle(for date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let dayName = dayFormatter.string(from: date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateText = dateFormatter.string(from: date)

        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        return "\(dayName), \(dateText)"
    }

    private func daySubtitle(for workouts: [Workout]) -> String {
        guard !workouts.isEmpty else { return "Rest day" }

        let classification = trainedClassificationNames(for: workouts)
        if classification.isEmpty {
            return workouts.count == 1 ? "1 workout" : "\(workouts.count) workouts"
        }

        return classification.joined(separator: ", ")
    }

    private func dayNumberText(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    private func shortWeekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func workoutsForDay(_ day: Date) -> [Workout] {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return workouts.filter { $0.startDate >= start && $0.startDate < end }
    }

    private func weekRangeText(for start: Date) -> String {
        rangeText(from: start, dayCount: 7)
    }

    private func rangeText(from start: Date, dayCount: Int) -> String {
        let end = Calendar.current.date(byAdding: .day, value: dayCount - 1, to: start) ?? start
        let startYear = Calendar.current.component(.year, from: start)
        let endYear = Calendar.current.component(.year, from: end)
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = startYear == endYear ? "MMM d" : "MMM d, yyyy"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
    }

    private func dayWorkoutTypes(for workouts: [Workout]) -> [WorkoutType] {
        workouts.reduce(into: [WorkoutType]()) { result, workout in
            guard !result.contains(workout.type) else { return }
            result.append(workout.type)
        }
    }

    private func trainedClassificationNames(for workouts: [Workout]) -> [String] {
        let categoryNames = workouts.flatMap { workout in
            (workout.categories ?? []).map(\.name)
        }
        let subcategoryNames = workouts.flatMap { workout in
            (workout.subcategories ?? []).map(\.name)
        }

        return uniqueCleanNames(categoryNames) + uniqueCleanNames(subcategoryNames)
    }

    private func trainedCategorySummaries(for workouts: [Workout]) -> [TrainedCategorySummary] {
        var categorySummariesByName: [String: TrainedCategorySummary] = [:]
        var subcategorySummariesByName: [String: TrainedCategorySummary] = [:]

        for workout in workouts {
            let categories = workout.categories ?? []
            let subcategories = workout.subcategories ?? []

            for category in categories {
                let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                let color = Color(hex: category.color) ?? workout.primaryWorkoutTintColor
                categorySummariesByName[name, default: TrainedCategorySummary(name: name, color: color, count: 0, kind: .category)].count += 1
            }

            for subcategory in subcategories {
                let name = subcategory.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                let color = subcategory.category.map { Color(hex: $0.color) ?? workout.primaryWorkoutTintColor } ?? workout.primaryWorkoutTintColor
                subcategorySummariesByName[name, default: TrainedCategorySummary(name: name, color: color, count: 0, kind: .subcategory)].count += 1
            }
        }

        return sortedSummaries(categorySummariesByName.values) + sortedSummaries(subcategorySummariesByName.values)
    }

    private func uniqueCleanNames(_ names: [String]) -> [String] {
        let cleaned = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(NSOrderedSet(array: cleaned)) as? [String] ?? []
    }

    private func sortedSummaries(_ summaries: Dictionary<String, TrainedCategorySummary>.Values) -> [TrainedCategorySummary] {
        summaries.sorted {
            if $0.count == $1.count {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.count > $1.count
        }
    }
}

private enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case week
    case last7Days

    var id: Self { self }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .last7Days:
            return "Last 7 Days"
        }
    }
}

private struct TrainedCategorySummary {
    enum Kind: String {
        case category
        case subcategory
    }

    let name: String
    let color: Color
    var count: Int
    let kind: Kind

    var id: String {
        "\(kind.rawValue)-\(name)"
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: Workout.self,
        WorkoutCategory.self,
        WorkoutSubcategory.self,
        WorkoutSubcategoryRating.self,
        configurations: config
    )
    let context = container.mainContext
    let calendar = Calendar.current

    let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
    let pull = WorkoutCategory(name: "Pull", color: "#4ECDC4", workoutType: .strength)
    let endurance = WorkoutCategory(name: "Endurance", color: "#45B7D1", workoutType: .running)
    let chest = WorkoutSubcategory(name: "Chest", category: push)
    let back = WorkoutSubcategory(name: "Back", category: pull)
    let tempo = WorkoutSubcategory(name: "Tempo", category: endurance)

    [push, pull, endurance].forEach { context.insert($0) }
    [chest, back, tempo].forEach { context.insert($0) }

    func addWorkout(
        type: WorkoutType,
        daysAgo: Int,
        minutes: Double,
        distance: Double? = nil,
        categories: [WorkoutCategory] = [],
        subcategories: [WorkoutSubcategory] = []
    ) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let workout = Workout(
            type: type,
            startDate: date,
            duration: minutes * 60,
            distance: distance,
            categories: categories,
            subcategories: subcategories
        )
        context.insert(workout)
    }

    addWorkout(type: .strength, daysAgo: 0, minutes: 45, categories: [push, pull], subcategories: [chest, back])
    addWorkout(type: .running, daysAgo: 1, minutes: 30, distance: 5.2, categories: [endurance], subcategories: [tempo])
    addWorkout(type: .yoga, daysAgo: 3, minutes: 25)
    addWorkout(type: .cycling, daysAgo: 4, minutes: 50, distance: 18.4)

    return NavigationStack {
        CalendarView()
    }
    .modelContainer(container)
}
