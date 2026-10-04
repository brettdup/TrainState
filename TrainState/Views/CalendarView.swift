import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workouts: [Workout] = []
    @State private var selectedWeekStart: Date = Calendar.current.startOfWeek(for: Date())
    @State private var weekPickerDate: Date = Date()
    @State private var showingWeekPicker = false
    @State private var displayMode: CalendarDisplayMode = .week
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    calendarControlsCard
                    if loadError == nil { weekSummaryCard }
                    agendaHeader
                    if let loadError {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(loadError, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                            Button("Try again") { loadDisplayedWorkouts() }
                                .buttonStyle(.bordered)
                        }
                        .padding(16)
                        .glassCard(showsShadow: false)
                    } else {
                        ForEach(agendaDays, id: \.self) { day in
                            daySection(for: day)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today", systemImage: "calendar.badge.clock") {
                        selectedWeekStart = Calendar.current.startOfWeek(for: Date())
                        displayMode = .week
                        selectedDay = Calendar.current.startOfDay(for: Date())
                    }
                }
            }
            .refreshable { loadDisplayedWorkouts() }
            .sheet(isPresented: $showingWeekPicker) {
                weekPickerSheet
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            loadDisplayedWorkouts()
        }
        .onChange(of: selectedWeekStart) { _, _ in
            reconcileSelectedDay()
            loadDisplayedWorkouts()
        }
        .onChange(of: displayMode) { _, _ in
            reconcileSelectedDay()
            loadDisplayedWorkouts()
        }
    }

    private var agendaDays: [Date] {
        selectedDay.map { [$0] } ?? displayedDays
    }

    private func reconcileSelectedDay() {
        guard let selectedDay else { return }
        if !displayedDays.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDay) }) {
            self.selectedDay = displayedDays.first
        }
    }

    private var agendaHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDay == nil ? "Weekly agenda" : "Daily agenda")
                    .font(.title3.bold())
                Text("Tap a day above to explore your training")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedDay != nil {
                Button("Show all") { selectedDay = nil }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
    }

    private func daySection(for day: Date) -> some View {
        let dayWorkouts = workoutsForDay(day)
        return VStack(alignment: .leading, spacing: 14) {
            daySectionHeader(for: day, workouts: dayWorkouts)
            if dayWorkouts.isEmpty {
                emptyDayRow(for: day)
            } else {
                ForEach(dayWorkouts, id: \.id) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            WorkoutRowView(workout: workout, showsChevron: false)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if workout.id != dayWorkouts.last?.id { Divider() }
                }
            }
        }
        .padding(18)
        .glassCard(showsShadow: false)
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

    private func emptyDayRow(for day: Date) -> some View {
        let isFuture = Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: Date())
        return HStack(spacing: 14) {
            Image(systemName: isFuture ? "calendar" : "leaf.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(isFuture ? "Training ahead" : "No workouts logged")
                    .font(.subheadline.weight(.semibold))
                Text(isFuture ? "Your logged workouts will appear here." : "No activity logged for this day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var weekNavigatorCard: some View {
        HStack(spacing: 12) {
            Button {
                moveDisplayedWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ThemeColor.primaryUi03())
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous week")
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
            .accessibilityHint("Choose a different week")
            .disabled(displayMode == .last7Days)

            Button {
                moveDisplayedWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ThemeColor.primaryUi03())
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next week")
            .disabled(displayMode == .last7Days || selectedWeekStart >= Calendar.current.startOfWeek(for: Date()))
            .opacity(displayMode == .last7Days ? 0.45 : 1)
        }
    }

    private var displayModePicker: some View {
        Picker("Calendar range", selection: $displayMode) {
            ForEach(CalendarDisplayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var calendarControlsCard: some View {
        VStack(spacing: 12) {
            displayModePicker
            weekNavigatorCard
            weekStripCard
        }
        .padding(16)
        .glassCard(showsShadow: false)
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) { dayTiles }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { dayTiles }
            }
        }
    }

    @ViewBuilder private var dayTiles: some View {
        ForEach(displayedDays, id: \.self) { day in
            calendarDayTile(day)
        }
    }

    private func calendarDayTile(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
        let dayWorkouts = workoutsForDay(day)
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 8) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(dayNumberText(for: day))
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                HStack(spacing: 3) {
                    ForEach(Array(dayWorkoutTypes(for: dayWorkouts).prefix(3)), id: \.self) { type in
                        Circle().fill(type.tintColor).frame(width: 5, height: 5)
                    }
                    if dayWorkouts.isEmpty {
                        Circle().fill(Color.secondary.opacity(0.2)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
                Circle()
                    .fill(isToday ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(minWidth: 30, maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(dayWorkouts.count) workouts\(isToday ? ", today" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var weekSummaryCard: some View {
        let summary = weekSummary(for: workoutsInDisplayedPeriod)
        let activeDays = Set(workoutsInDisplayedPeriod.map { Calendar.current.startOfDay(for: $0.startDate) }).count
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TRAINING TIME")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(summary.duration)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text(displayedRangeSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { summaryMetrics(count: summary.count, days: activeDays, distance: summary.distance) }
                VStack(alignment: .leading, spacing: 12) { summaryMetrics(count: summary.count, days: activeDays, distance: summary.distance) }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            trainingDistribution
            categorySummaryChips
        }
        .padding(20)
        .glassCard(showsShadow: false)
    }

    @ViewBuilder private func summaryMetrics(count: Int, days: Int, distance: Double) -> some View {
        Label("\(count) workouts", systemImage: "figure.run")
        Label("\(days) active days", systemImage: "calendar")
        if distance > 0 {
            Label(String(format: "%.1f km", distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }
    }

    private var trainingDistribution: some View {
        let types = dayWorkoutTypes(for: workoutsInDisplayedPeriod)
        let total = workoutsInDisplayedPeriod.reduce(0) { $0 + max($1.duration, 0) }
        return Group {
            if total > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(types, id: \.self) { type in
                                let duration = workoutsInDisplayedPeriod.filter { $0.type == type }.reduce(0) { $0 + max($1.duration, 0) }
                                Rectangle().fill(type.tintColor)
                                    .frame(width: geometry.size.width * CGFloat(duration / total))
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 7)
                    .accessibilityHidden(true)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(types, id: \.self) { type in
                                let typeWorkouts = workoutsInDisplayedPeriod.filter { $0.type == type }
                                Label("\(type.rawValue) · \(weekSummary(for: typeWorkouts).duration)", systemImage: type.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(type.tintColor)
                            }
                        }
                    }
                }
            }
        }
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
        do {
            workouts = try modelContext.fetch(descriptor)
            loadError = nil
        } catch {
            workouts = []
            loadError = "Couldn't load your workouts. Please try again."
        }
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
        let totalMinutes = max(Int(totalDuration / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let durationText = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
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
        guard !workouts.isEmpty else { return "No logged activity" }

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

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        var calendar = self
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
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

    return CalendarView()
        .modelContainer(container)
}
