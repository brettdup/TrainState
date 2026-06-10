import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import HealthKit

struct AnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @AppStorage("weeklyGoalWorkouts") private var weeklyGoalWorkouts: Int = 4
    @AppStorage("weeklyGoalMinutes") private var weeklyGoalMinutes: Int = 180
    @AppStorage("weeklyGoalDistance") private var weeklyGoalDistance: Double = 10
    @AppStorage("analyticsWorkoutTypeGoals") private var analyticsWorkoutTypeGoalsData: Data = Data()
    @AppStorage("hasEnabledWorkoutReminders") private var hasEnabledWorkoutReminders = false
    @AppStorage("analyticsWorkoutGoalMin") private var workoutGoalMin: Int = 1
    @AppStorage("analyticsWorkoutGoalMax") private var workoutGoalMax: Int = 14
    @AppStorage("analyticsMinuteGoalMin") private var minuteGoalMin: Int = 30
    @AppStorage("analyticsMinuteGoalMax") private var minuteGoalMax: Int = 1000
    @AppStorage("analyticsDistanceGoalMin") private var distanceGoalMin: Double = 1
    @AppStorage("analyticsDistanceGoalMax") private var distanceGoalMax: Double = 300

    @State private var selectedFilter: AnalyticsWorkoutFilter = .all
    @State private var workoutTypeGoals: [String: AnalyticsWorkoutGoal] = [:]
    @State private var goalSetupFilterID: String?
    @State private var goalSetupDraft = AnalyticsWorkoutGoal(workouts: 1, minutes: 30, distance: 1)
    @State private var showAllPersonalBests = false
    @State private var weeklyRecapSharePayload: WeeklyRecapShareImage?
    @State private var weeklyRecapSharePreview: Image?
    @State private var isGoalRangeSettingsExpanded = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.10),
                        ThemeColor.primaryUi02().opacity(colorScheme == .dark ? 0.35 : 0.65),
                        ThemeColor.primaryUi01()
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    GlassEffectContainerWrapper(spacing: 16) {
                        LazyVStack(spacing: 16) {
                            filterCard
                            weeklySummaryCard
                            goalsCard
                            streakCard
                            strengthHistoryCard
                            personalBestsCard
                            moreInsightsCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SubcategoryLastLoggedView()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .accessibilityLabel("Open last trained")
                }
            }
            .task(id: weeklyRecapShareSignature) {
                refreshWeeklyRecapSharePayload()
            }
            .onAppear {
                loadWorkoutTypeGoals()
                validateSelectedFilter()
            }
            .onChange(of: workouts.map(\.id)) { _, _ in
                validateSelectedFilter()
            }
            .onChange(of: analyticsWorkoutTypeGoalsData) { _, _ in
                loadWorkoutTypeGoals()
            }
        }
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scope")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Menu {
                ForEach(availableWorkoutFilters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        if selectedFilter == filter {
                            Label(filter.title, systemImage: "checkmark")
                        } else {
                            Text(filter.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedFilter.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedFilter.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(filteredWorkouts.count) logged workout\(filteredWorkouts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCard()
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This Week")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(weeklyRecapHeadline)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
            }

            HStack(spacing: 12) {
                analyticsMetricTile(title: "Workouts", value: "\(workoutsThisWeek.count)", icon: "figure.run")
                analyticsMetricTile(title: "Minutes", value: "\(weeklyMinutes)", icon: "clock")
                analyticsMetricTile(title: "Streak", value: "\(currentDailyStreak)d", icon: "flame")
            }

            shareWeeklyRecapButton
        }
        .padding(16)
        .glassCard()
    }

    @ViewBuilder
    private var shareWeeklyRecapButton: some View {
        if let weeklyRecapSharePayload {
            ShareLink(
                item: weeklyRecapSharePayload,
                preview: SharePreview(
                    "Exercise Pal Weekly Recap",
                    image: weeklyRecapSharePreview ?? Image(systemName: "chart.bar.fill")
                )
            ) {
                Label("Share Weekly Recap", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColor.primaryUi03())
                    )
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                Label("Preparing share card", systemImage: "square.and.arrow.up")
                Spacer()
                ProgressView()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 11)
        }
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(
                title: selectedFilter == .all ? "Goals" : "\(selectedFilter.title) Goals",
                subtitle: activeGoal == nil ? addGoalsPromptText : "Adjust weekly targets for the selected workout scope.",
                icon: "target"
            )

            if let activeGoal {
                progressCardRow(
                    title: "Workouts",
                    value: "\(weeklySummary.count) of \(activeGoal.workouts)",
                    progress: workoutGoalProgress
                )
                progressCardRow(
                    title: "Minutes",
                    value: "\(weeklyMinutes) of \(activeGoal.minutes)",
                    progress: minuteGoalProgress
                )
                if showsDistanceGoal {
                    progressCardRow(
                        title: "Distance",
                        value: String(format: "%.1f of %.1f km", weeklyDistance, activeGoal.distance),
                        progress: distanceGoalProgress
                    )
                }

                Divider()

                goalSliderControl(
                    title: "Workout Goal",
                    valueText: "\(activeGoal.workouts)",
                    systemImage: "figure.run",
                    value: workoutGoalBinding,
                    range: workoutGoalRange,
                    step: 1
                )
                goalSliderControl(
                    title: "Minutes Goal",
                    valueText: "\(activeGoal.minutes) min",
                    systemImage: "clock",
                    value: minuteGoalBinding,
                    range: minuteGoalRange,
                    step: 15
                )
                if showsDistanceGoal {
                    goalSliderControl(
                        title: "Distance Goal",
                        valueText: String(format: "%.1f km", activeGoal.distance),
                        systemImage: "arrow.left.and.right",
                        value: distanceGoalBinding,
                        range: distanceGoalRange,
                        step: 1
                    )
                }

                goalRangeSettings
            } else if goalSetupFilterID == selectedFilter.goalStorageKey {
                goalSetupCardRows
            } else {
                Button {
                    beginGoalSetup()
                } label: {
                    Label("Add Goals", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
    }

    private var goalSetupCardRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            goalSliderControl(
                title: "Workout Goal",
                valueText: "\(goalSetupDraft.workouts)",
                systemImage: "figure.run",
                value: $goalSetupDraft.workouts,
                range: workoutGoalRange,
                step: 1
            )
            goalSliderControl(
                title: "Minutes Goal",
                valueText: "\(goalSetupDraft.minutes) min",
                systemImage: "clock",
                value: $goalSetupDraft.minutes,
                range: minuteGoalRange,
                step: 15
            )
            if showsDistanceGoal {
                goalSliderControl(
                    title: "Distance Goal",
                    valueText: String(format: "%.1f km", goalSetupDraft.distance),
                    systemImage: "arrow.left.and.right",
                    value: $goalSetupDraft.distance,
                    range: distanceGoalRange,
                    step: 1
                )
            }
            goalRangeSettings
            HStack(spacing: 10) {
                Button {
                    save(goal: goalSetupDraft)
                    goalSetupFilterID = nil
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) {
                    goalSetupFilterID = nil
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(title: "Streaks", subtitle: "Consistency across your logged history.", icon: "flame")
            HStack(spacing: 12) {
                analyticsMetricTile(title: "Current", value: "\(currentDailyStreak)d", icon: "flame")
                analyticsMetricTile(title: "Best", value: "\(bestDailyStreak)d", icon: "trophy")
                analyticsMetricTile(title: "Weekly", value: "\(weeklyGoalStreak)", icon: "calendar")
            }
        }
        .padding(16)
        .glassCard()
    }

    private var strengthHistoryCard: some View {
        NavigationLink {
            SubcategoryLastLoggedView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Last Trained")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Review strength areas and exercise history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(title: "Personal Bests", subtitle: "\(exercisePRs.count) tracked lift\(exercisePRs.count == 1 ? "" : "s")", icon: "medal")

            if exercisePRs.isEmpty {
                Text("Log weighted lifts to track top sets and estimated 1RM.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visiblePersonalBests, id: \.exerciseName) { pr in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pr.exerciseName)
                                .font(.subheadline.weight(.semibold))
                            Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: "%.1f kg", pr.topSetWeight))
                                .font(.subheadline.weight(.bold))
                            Text(String(format: "%.1f kg 1RM", pr.estimatedOneRepMax))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if exercisePRs.count > 5 {
                    Button(showAllPersonalBests ? "Show Top 5" : "View All") {
                        showAllPersonalBests.toggle()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private var moreInsightsCard: some View {
        DisclosureGroup {
            nextSessionGuidanceRows
            smartPROpportunityRows
            adaptivePlanRows
            untrainedCategoryRows
            persistentSurfaceRows
            allTimeRows
        } label: {
            Label("More Insights", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
        }
        .padding(16)
        .glassCard(prominence: .regular)
    }

    private var filterSection: some View {
        Section {
            Menu {
                ForEach(availableWorkoutFilters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        if selectedFilter == filter {
                            Label(filter.title, systemImage: "checkmark")
                        } else {
                            Text(filter.title)
                        }
                    }
                }
            } label: {
                HStack {
                    Label("Workout Type", systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedFilter.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var weeklySummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text(weeklyRecapHeadline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    metricTile(title: "Workouts", value: "\(workoutsThisWeek.count)")
                    metricTile(title: "Minutes", value: "\(weeklyMinutes)")
                    metricTile(title: "Streak", value: "\(currentDailyStreak)d")
                }
            }
            .padding(.vertical, 4)

            if let weeklyRecapSharePayload {
                ShareLink(
                    item: weeklyRecapSharePayload,
                    preview: SharePreview(
                        "Exercise Pal Weekly Recap",
                        image: weeklyRecapSharePreview ?? Image(systemName: "chart.bar.fill")
                    )
                ) {
                    Label("Share Weekly Recap", systemImage: "square.and.arrow.up")
                }
            } else {
                HStack {
                    Label("Preparing share card", systemImage: "square.and.arrow.up")
                    Spacer()
                    ProgressView()
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("This Week")
        }
    }

    private var goalsSection: some View {
        Section {
            if let activeGoal {
                progressRow(
                    title: "Workouts",
                    value: "\(weeklySummary.count) of \(activeGoal.workouts)",
                    progress: workoutGoalProgress
                )
                progressRow(
                    title: "Minutes",
                    value: "\(weeklyMinutes) of \(activeGoal.minutes)",
                    progress: minuteGoalProgress
                )
                if showsDistanceGoal {
                    progressRow(
                        title: "Distance",
                        value: String(format: "%.1f of %.1f km", weeklyDistance, activeGoal.distance),
                        progress: distanceGoalProgress
                    )
                }

                goalSliderControl(
                    title: "Workout Goal",
                    valueText: "\(activeGoal.workouts)",
                    systemImage: "figure.run",
                    value: workoutGoalBinding,
                    range: workoutGoalRange,
                    step: 1
                )
                goalSliderControl(
                    title: "Minutes Goal",
                    valueText: "\(activeGoal.minutes) min",
                    systemImage: "clock",
                    value: minuteGoalBinding,
                    range: minuteGoalRange,
                    step: 15
                )
                if showsDistanceGoal {
                    goalSliderControl(
                        title: "Distance Goal",
                        valueText: String(format: "%.1f km", activeGoal.distance),
                        systemImage: "arrow.left.and.right",
                        value: distanceGoalBinding,
                        range: distanceGoalRange,
                        step: 1
                    )
                }
            } else {
                if goalSetupFilterID == selectedFilter.goalStorageKey {
                    goalSetupRows
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No goals for \(selectedFilter.title) yet.")
                            .font(.body.weight(.semibold))
                        Text(addGoalsPromptText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        beginGoalSetup()
                    } label: {
                        Label("Add Goals", systemImage: "plus.circle")
                    }
                }
            }
        } header: {
            Text(selectedFilter == .all ? "Goals" : "\(selectedFilter.title) Goals")
        } footer: {
            if activeGoal != nil {
                Text(goalForecastText)
            }
        }
    }

    private var goalSetupRows: some View {
        Group {
            goalSliderControl(
                title: "Workout Goal",
                valueText: "\(goalSetupDraft.workouts)",
                systemImage: "figure.run",
                value: $goalSetupDraft.workouts,
                range: workoutGoalRange,
                step: 1
            )
            goalSliderControl(
                title: "Minutes Goal",
                valueText: "\(goalSetupDraft.minutes) min",
                systemImage: "clock",
                value: $goalSetupDraft.minutes,
                range: minuteGoalRange,
                step: 15
            )
            if showsDistanceGoal {
                goalSliderControl(
                    title: "Distance Goal",
                    valueText: String(format: "%.1f km", goalSetupDraft.distance),
                    systemImage: "arrow.left.and.right",
                    value: $goalSetupDraft.distance,
                    range: distanceGoalRange,
                    step: 1
                )
            }
            Button {
                save(goal: goalSetupDraft)
                goalSetupFilterID = nil
            } label: {
                Label("Save Goals", systemImage: "checkmark.circle")
            }
            Button(role: .cancel) {
                goalSetupFilterID = nil
            } label: {
                Text("Cancel")
            }
        }
    }

    private var streakSection: some View {
        Section("Streaks") {
            LabeledContent("Current Daily Streak", value: "\(currentDailyStreak) days")
            LabeledContent("Best Daily Streak", value: "\(bestDailyStreak) days")
            LabeledContent("Weekly Goal Streak", value: "\(weeklyGoalStreak) weeks")
        }
    }

    private var strengthHistorySection: some View {
        Section {
            NavigationLink {
                SubcategoryLastLoggedView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Trained")
                        Text("Review strength areas and exercise history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var personalBestsSection: some View {
        Section {
            if exercisePRs.isEmpty {
                Text("Log weighted lifts (for example Bench Press) to track personal bests.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visiblePersonalBests, id: \.exerciseName) { pr in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pr.exerciseName)
                            .font(.body)
                        Text(
                            String(
                                format: "%.1f kg top set · %.1f kg est 1RM · %@",
                                pr.topSetWeight,
                                pr.estimatedOneRepMax,
                                pr.date.formatted(date: .abbreviated, time: .omitted)
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                if exercisePRs.count > 5 {
                    Button(showAllPersonalBests ? "Show Top 5" : "View All") {
                        showAllPersonalBests.toggle()
                    }
                }
            }
        } header: {
            Text("Personal Bests")
        }
    }

    private var moreInsightsSection: some View {
        Section {
            DisclosureGroup {
                nextSessionGuidanceRows
                smartPROpportunityRows
                adaptivePlanRows
                untrainedCategoryRows
                persistentSurfaceRows
                allTimeRows
            } label: {
                Label("More Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }

    @ViewBuilder
    private var smartPROpportunityRows: some View {
        Group {
            insightHeader("PR Opportunities")
            if smartPROpportunities.isEmpty {
                Text("No near-PR lifts right now. Keep logging sets and we’ll surface opportunities.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(smartPROpportunities.prefix(3), id: \.exerciseName) { opportunity in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opportunity.exerciseName)
                            .font(.subheadline.weight(.semibold))
                        Text(String(format: "You’re at %.0f%% of your PR. Latest %.1f kg vs PR %.1f kg.", opportunity.progressToPR * 100, opportunity.latestTopSet, opportunity.prTopSet))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var adaptivePlanRows: some View {
        Group {
            insightHeader("Adaptive Plan")
            if adaptiveRecommendations.isEmpty {
                Text("No clear gaps yet. Log a few more workouts for tailored recommendations.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(adaptiveRecommendations, id: \.name) { rec in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rec.name)
                                .font(.subheadline.weight(.semibold))
                            Text(rec.reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var untrainedCategoryRows: some View {
        Group {
            insightHeader("Not Trained Yet")
            if untrainedCategories.isEmpty {
                Text("Every available category for this filter has training history.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(untrainedCategories, id: \.id) { category in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: category.color) ?? .secondary)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(category.activityDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nextSessionGuidanceRows: some View {
        Group {
            insightHeader("Next Session")
            if nextSessionRecommendations.isEmpty {
                Text("Log a few more workouts to unlock session guidance.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nextSessionRecommendations, id: \.title) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var persistentSurfaceRows: some View {
        Group {
            insightHeader("Setup")
            persistentSurfaceRow(
                title: "HealthKit integration",
                status: importedHealthKitWorkoutCount > 0 ? "Connected" : "Not connected",
                detail: importedHealthKitWorkoutCount > 0
                    ? "\(importedHealthKitWorkoutCount) workouts linked from Health."
                    : "Import recent workouts from the Workouts tab Health menu."
            )
            persistentSurfaceRow(
                title: "Workout reminders",
                status: hasEnabledWorkoutReminders ? "Enabled" : "Disabled",
                detail: hasEnabledWorkoutReminders
                    ? "You have routine reminders to return and log."
                    : "Enable reminders to keep consistency during missed windows."
            )
            persistentSurfaceRow(
                title: "Live sessions",
                status: liveSessionUsageStatus,
                detail: liveSessionUsageDetail
            )
        }
    }

    private func persistentSurfaceRow(title: String, status: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func cardHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private func analyticsMetricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .monospacedDigit()

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColor.primaryUi03())
        )
    }

    private func progressCardRow(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ProgressView(value: progress)
                .tint(Color.accentColor)
        }
    }

    private var goalRangeSettings: some View {
        DisclosureGroup(isExpanded: $isGoalRangeSettingsExpanded) {
            VStack(spacing: 12) {
                goalRangeRow(
                    title: "Workouts",
                    minValue: workoutGoalMinBinding,
                    maxValue: workoutGoalMaxBinding,
                    suffix: ""
                )
                goalRangeRow(
                    title: "Minutes",
                    minValue: minuteGoalMinBinding,
                    maxValue: minuteGoalMaxBinding,
                    suffix: "min"
                )
                if showsDistanceGoal {
                    goalRangeRow(
                        title: "Distance",
                        minValue: distanceGoalMinBinding,
                        maxValue: distanceGoalMaxBinding,
                        suffix: "km"
                    )
                }

                Button {
                    isGoalRangeSettingsExpanded = false
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        } label: {
            Label("Slider Range", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
    }

    private func goalRangeRow(
        title: String,
        minValue: Binding<Int>,
        maxValue: Binding<Int>,
        suffix: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(width: 68, alignment: .leading)

            goalRangeField("Min", value: minValue, suffix: suffix)
            goalRangeField("Max", value: maxValue, suffix: suffix)
        }
    }

    private func goalRangeRow(
        title: String,
        minValue: Binding<Double>,
        maxValue: Binding<Double>,
        suffix: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(width: 68, alignment: .leading)

            goalRangeField("Min", value: minValue, suffix: suffix)
            goalRangeField("Max", value: maxValue, suffix: suffix)
        }
    }

    private func goalRangeField(_ title: String, value: Binding<Int>, suffix: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.caption.weight(.bold))
                .monospacedDigit()
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeColor.primaryUi03())
        )
    }

    private func goalRangeField(_ title: String, value: Binding<Double>, suffix: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.caption.weight(.bold))
                .monospacedDigit()
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeColor.primaryUi03())
        )
    }

    private func goalSliderControl(
        title: String,
        valueText: String,
        systemImage: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        let doubleValue = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )

        return goalSliderControl(
            title: title,
            valueText: valueText,
            systemImage: systemImage,
            value: doubleValue,
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step)
        )
    }

    private func goalSliderControl(
        title: String,
        valueText: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(valueText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }

            Slider(value: value, in: range, step: step)
                .tint(Color.accentColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColor.primaryUi03())
        )
    }

    @ViewBuilder
    private var allTimeRows: some View {
        Group {
            insightHeader("All Time")
            LabeledContent("Workouts", value: "\(allTimeSummary.count)")
            LabeledContent("Duration", value: allTimeSummary.duration)
            if allTimeSummary.distance > 0 {
                LabeledContent("Distance", value: String(format: "%.1f km", allTimeSummary.distance))
            }
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressRow(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
        }
    }

    private func insightHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 8)
    }

    private var filteredWorkouts: [Workout] {
        switch selectedFilter {
        case .all:
            return workouts
        case .apple(let activityType):
            return workouts.filter { $0.resolvedAppleWorkoutActivityType == activityType }
        }
    }

    private var availableWorkoutFilters: [AnalyticsWorkoutFilter] {
        let loggedActivityTypes = Set(workouts.map(\.resolvedAppleWorkoutActivityType))
        let loggedFilters = loggedActivityTypes
            .sorted { $0.displayName < $1.displayName }
            .map { AnalyticsWorkoutFilter.apple($0) }
        return [.all] + loggedFilters
    }

    private func validateSelectedFilter() {
        guard !availableWorkoutFilters.contains(selectedFilter) else { return }
        selectedFilter = .all
    }

    private var filteredSubcategories: [WorkoutSubcategory] {
        switch selectedFilter {
        case .all:
            return subcategories
        case .apple(let activityType):
            return subcategories.filter { subcategory in
                guard let category = subcategory.category else { return false }
                return category.matches(
                    appleWorkoutActivityType: activityType,
                    fallbackWorkoutType: activityType.mappedWorkoutType
                )
            }
        }
    }

    private var categoriesForFilter: [WorkoutCategory] {
        switch selectedFilter {
        case .all:
            return categories
        case .apple(let activityType):
            return WorkoutCategory.categoriesForAppleWorkout(
                activityType: activityType,
                fallbackWorkoutType: activityType.mappedWorkoutType,
                from: categories
            )
        }
    }

    private var untrainedCategories: [WorkoutCategory] {
        let trainedCategoryIDs: Set<UUID> = Set(filteredWorkouts.flatMap { workout in
            var ids = workout.categories?.map(\.id) ?? []
            ids.append(contentsOf: (workout.subcategories ?? []).compactMap { $0.category?.id })
            return ids
        })

        return categoriesForFilter
            .filter { !trainedCategoryIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var weeklySummary: (count: Int, duration: String, distance: Double) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return (0, formattedDuration(0), 0)
        }
        let weekWorkouts = filteredWorkouts.filter { weekInterval.contains($0.startDate) }
        let duration = weekWorkouts.reduce(0) { $0 + $1.duration }
        let distance = weekWorkouts.reduce(0) { $0 + ($1.distance ?? 0) }
        return (weekWorkouts.count, formattedDuration(duration), distance)
    }

    private var allTimeSummary: (count: Int, duration: String, distance: Double) {
        let duration = filteredWorkouts.reduce(0) { $0 + $1.duration }
        let distance = filteredWorkouts.reduce(0) { $0 + ($1.distance ?? 0) }
        return (filteredWorkouts.count, formattedDuration(duration), distance)
    }

    private var weeklyMinutes: Int {
        Int(workoutsThisWeek.reduce(0) { $0 + $1.duration } / 60.0)
    }

    private var weeklyDistance: Double {
        workoutsThisWeek.reduce(0) { $0 + ($1.distance ?? 0) }
    }

    private var workoutsThisWeek: [Workout] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return filteredWorkouts.filter { weekInterval.contains($0.startDate) }
    }

    private var workoutGoalProgress: Double {
        guard let activeGoal else { return 0 }
        return min(Double(workoutsThisWeek.count) / Double(max(activeGoal.workouts, 1)), 1)
    }

    private var minuteGoalProgress: Double {
        guard let activeGoal else { return 0 }
        return min(Double(weeklyMinutes) / Double(max(activeGoal.minutes, 1)), 1)
    }

    private var distanceGoalProgress: Double {
        guard let activeGoal else { return 0 }
        return min(weeklyDistance / max(activeGoal.distance, 1), 1)
    }

    private var weeklyRecapHeadline: String {
        if workoutsThisWeek.isEmpty {
            return "No workouts logged yet this week. Start today and build momentum."
        }
        guard activeGoal != nil else {
            return "\(workoutsThisWeek.count) \(selectedFilter.title.lowercased()) workout\(workoutsThisWeek.count == 1 ? "" : "s") logged this week."
        }
        if workoutGoalProgress >= 1 && minuteGoalProgress >= 1 {
            return "You hit both weekly goals. This is a strong consistency week."
        }
        if workoutGoalProgress >= 1 {
            return "Workout target reached. Add minutes to push the week further."
        }
        return "You are \(workoutsRemainingThisWeek) workout\(workoutsRemainingThisWeek == 1 ? "" : "s") away from goal."
    }

    private var daysRemainingInWeek: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return 1 }
        let days = calendar.dateComponents([.day], from: tomorrow, to: weekInterval.end).day ?? 0
        return max(days, 1)
    }

    private var workoutsRemainingThisWeek: Int {
        guard let activeGoal else { return 0 }
        return max(activeGoal.workouts - workoutsThisWeek.count, 0)
    }

    private var minutesRemainingThisWeek: Int {
        guard let activeGoal else { return 0 }
        return max(activeGoal.minutes - weeklyMinutes, 0)
    }

    private var distanceRemainingThisWeek: Double {
        guard let activeGoal else { return 0 }
        return max(activeGoal.distance - weeklyDistance, 0)
    }

    private var weeklyWorkoutPaceForecast: String {
        let perDay = Double(workoutsRemainingThisWeek) / Double(daysRemainingInWeek)
        if workoutsRemainingThisWeek == 0 { return "On track: goal reached" }
        return String(format: "Need %.1f workouts/day for %d day(s)", perDay, daysRemainingInWeek)
    }

    private var weeklyMinutePaceForecast: String {
        let perDay = Double(minutesRemainingThisWeek) / Double(daysRemainingInWeek)
        if minutesRemainingThisWeek == 0 { return "On track: goal reached" }
        return String(format: "Need %.0f min/day for %d day(s)", perDay, daysRemainingInWeek)
    }

    private var weeklyDistancePaceForecast: String {
        let perDay = distanceRemainingThisWeek / Double(daysRemainingInWeek)
        if distanceRemainingThisWeek == 0 { return "Distance goal reached" }
        return String(format: "Need %.1f km/day for %d day(s)", perDay, daysRemainingInWeek)
    }

    private var goalForecastText: String {
        var parts = [weeklyWorkoutPaceForecast, weeklyMinutePaceForecast]
        if showsDistanceGoal {
            parts.append(weeklyDistancePaceForecast)
        }
        return parts.joined(separator: ". ") + "."
    }

    private var currentDailyStreak: Int {
        let calendar = Calendar.current
        let days = Set(filteredWorkouts.map { calendar.startOfDay(for: $0.startDate) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) {
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private var bestDailyStreak: Int {
        let calendar = Calendar.current
        let sortedDays = Set(filteredWorkouts.map { calendar.startOfDay(for: $0.startDate) }).sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for index in 1..<sortedDays.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: sortedDays[index - 1]),
               calendar.isDate(sortedDays[index], inSameDayAs: expected) {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }

    private var weeklyGoalStreak: Int {
        guard let activeGoal else { return 0 }
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        var streak = 0
        var cursor = thisWeekStart

        while true {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            let count = filteredWorkouts.filter { $0.startDate >= cursor && $0.startDate < nextWeek }.count
            if count >= activeGoal.workouts {
                streak += 1
            } else {
                break
            }
            guard let previousWeek = calendar.date(byAdding: .day, value: -7, to: cursor) else { break }
            cursor = previousWeek
        }
        return streak
    }

    private var exercisePRs: [ExercisePR] {
        var bestByExercise: [String: ExercisePR] = [:]

        for workout in filteredWorkouts {
            for exercise in workout.exercises ?? [] {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let weight = exercise.weight, weight > 0 else { continue }
                let reps = max(exercise.reps ?? 1, 1)
                let estimatedOneRepMax = weight * (1 + Double(reps) / 30.0)

                let current = bestByExercise[name]
                if current == nil || estimatedOneRepMax > current!.estimatedOneRepMax {
                    bestByExercise[name] = ExercisePR(
                        exerciseName: name,
                        topSetWeight: weight,
                        estimatedOneRepMax: estimatedOneRepMax,
                        date: workout.startDate
                    )
                }
            }
        }

        return bestByExercise.values.sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
    }

    private var visiblePersonalBests: [ExercisePR] {
        showAllPersonalBests ? exercisePRs : Array(exercisePRs.prefix(5))
    }

    private var smartPROpportunities: [SmartPROpportunity] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let prs = Dictionary(uniqueKeysWithValues: exercisePRs.map { ($0.exerciseName, $0) })
        var recentBest: [String: Double] = [:]

        for workout in filteredWorkouts where workout.startDate >= twoWeeksAgo {
            for exercise in workout.exercises ?? [] {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let weight = exercise.weight, weight > 0 else { continue }
                recentBest[name] = max(recentBest[name] ?? 0, weight)
            }
        }

        return recentBest.compactMap { name, latest in
            guard let pr = prs[name], pr.topSetWeight > 0 else { return nil }
            let progress = latest / pr.topSetWeight
            guard progress >= 0.9 && progress < 1 else { return nil }
            return SmartPROpportunity(
                exerciseName: name,
                latestTopSet: latest,
                prTopSet: pr.topSetWeight,
                progressToPR: progress
            )
        }
        .sorted { $0.progressToPR > $1.progressToPR }
    }

    private var adaptiveRecommendations: [AdaptiveRecommendation] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let recentWorkouts = filteredWorkouts.filter { $0.startDate >= twoWeeksAgo }

        let counts: [UUID: Int] = filteredSubcategories.reduce(into: [:]) { result, subcategory in
            let count = recentWorkouts.reduce(0) { partial, workout in
                let hasSubcategory = (workout.subcategories ?? []).contains { $0.id == subcategory.id }
                return partial + (hasSubcategory ? 1 : 0)
            }
            result[subcategory.id] = count
        }

        return filteredSubcategories
            .sorted { (counts[$0.id] ?? 0) < (counts[$1.id] ?? 0) }
            .prefix(3)
            .map { subcategory in
                let hits = counts[subcategory.id] ?? 0
                let reason = hits == 0
                    ? "No sessions in the last 14 days. Add this to your next workout."
                    : "Only \(hits) session\(hits == 1 ? "" : "s") in the last 14 days. Consider increasing frequency."
                return AdaptiveRecommendation(name: subcategory.name, reason: reason)
            }
    }

    private var importedHealthKitWorkoutCount: Int {
        filteredWorkouts.filter { ($0.hkUUID ?? "").isEmpty == false }.count
    }

    private var liveSessionUsageStatus: String {
        let strengthCount = filteredWorkouts.filter { $0.type == .strength }.count
        return strengthCount > 0 ? "Active" : "Not used"
    }

    private var liveSessionUsageDetail: String {
        let strengthCount = filteredWorkouts.filter { $0.type == .strength }.count
        if strengthCount > 0 {
            return "You logged \(strengthCount) strength sessions. Keep using live mode for in-session tracking."
        }
        return "Start a live strength session from Add Workout for real-time logging."
    }

    private var nextSessionRecommendations: [SessionGuidanceItem] {
        var items: [SessionGuidanceItem] = []

        if let topPR = smartPROpportunities.first {
            items.append(
                SessionGuidanceItem(
                    title: "Push a near-PR lift",
                    detail: "\(topPR.exerciseName): latest \(String(format: "%.1f", topPR.latestTopSet)) kg, PR \(String(format: "%.1f", topPR.prTopSet)) kg."
                )
            )
        }

        if let firstGap = adaptiveRecommendations.first {
            items.append(
                SessionGuidanceItem(
                    title: "Train a missed area",
                    detail: "\(firstGap.name): \(firstGap.reason)"
                )
            )
        }

        if workoutsRemainingThisWeek > 0 {
            items.append(
                SessionGuidanceItem(
                    title: "Close your weekly goal gap",
                    detail: "You need \(workoutsRemainingThisWeek) more workout\(workoutsRemainingThisWeek == 1 ? "" : "s") this week."
                )
            )
        }

        return Array(items.prefix(3))
    }

    private func recapPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), in: Capsule())
    }

    private func shareMetricPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.15), in: Capsule())
    }

    private var weeklyRecapShareSignature: String {
        "\(workoutsThisWeek.count)-\(weeklyMinutes)-\(currentDailyStreak)-\(weeklyRecapHeadline)"
    }

    private var activeGoal: AnalyticsWorkoutGoal? {
        switch selectedFilter {
        case .all:
            return AnalyticsWorkoutGoal(
                workouts: weeklyGoalWorkouts,
                minutes: weeklyGoalMinutes,
                distance: weeklyGoalDistance
            )
        case .apple:
            return workoutTypeGoals[selectedFilter.goalStorageKey]
        }
    }

    private var showsDistanceGoal: Bool {
        guard case .apple(let activityType) = selectedFilter else { return weeklyDistance > 0 }
        return activityType.prefersDistanceGoal || filteredWorkouts.contains { ($0.distance ?? 0) > 0 }
    }

    private var addGoalsPromptText: String {
        if showsDistanceGoal {
            return "Add weekly workout, minute, and distance goals for this workout type."
        }
        return "Add weekly workout and minute goals for this workout type."
    }

    private func beginGoalSetup() {
        goalSetupFilterID = selectedFilter.goalStorageKey
        goalSetupDraft = AnalyticsWorkoutGoal(
            workouts: workoutGoalRange.lowerBound,
            minutes: minuteGoalRange.lowerBound,
            distance: distanceGoalRange.lowerBound
        )
    }

    private var workoutGoalRange: ClosedRange<Int> {
        min(workoutGoalMin, workoutGoalMax - 1)...max(workoutGoalMax, workoutGoalMin + 1)
    }

    private var minuteGoalRange: ClosedRange<Int> {
        min(minuteGoalMin, minuteGoalMax - 15)...max(minuteGoalMax, minuteGoalMin + 15)
    }

    private var distanceGoalRange: ClosedRange<Double> {
        min(distanceGoalMin, distanceGoalMax - 1)...max(distanceGoalMax, distanceGoalMin + 1)
    }

    private var workoutGoalBinding: Binding<Int> {
        Binding(
            get: { clamp(activeGoal?.workouts ?? workoutGoalRange.lowerBound, to: workoutGoalRange) },
            set: { newValue in
                var goal = activeGoal ?? AnalyticsWorkoutGoal(workouts: 1, minutes: 30, distance: 1)
                goal.workouts = clamp(newValue, to: workoutGoalRange)
                save(goal: goal)
            }
        )
    }

    private var minuteGoalBinding: Binding<Int> {
        Binding(
            get: { clamp(activeGoal?.minutes ?? minuteGoalRange.lowerBound, to: minuteGoalRange) },
            set: { newValue in
                var goal = activeGoal ?? AnalyticsWorkoutGoal(workouts: 1, minutes: 30, distance: 1)
                goal.minutes = clamp(newValue, to: minuteGoalRange)
                save(goal: goal)
            }
        )
    }

    private var distanceGoalBinding: Binding<Double> {
        Binding(
            get: { clamp(activeGoal?.distance ?? distanceGoalRange.lowerBound, to: distanceGoalRange) },
            set: { newValue in
                var goal = activeGoal ?? AnalyticsWorkoutGoal(workouts: 1, minutes: 30, distance: 1)
                goal.distance = clamp(newValue, to: distanceGoalRange)
                save(goal: goal)
            }
        )
    }

    private var workoutGoalMinBinding: Binding<Int> {
        Binding(
            get: { workoutGoalRange.lowerBound },
            set: { newValue in
                workoutGoalMin = max(newValue, 1)
                if workoutGoalMax <= workoutGoalMin {
                    workoutGoalMax = workoutGoalMin + 1
                }
                clampActiveGoalToRanges()
            }
        )
    }

    private var workoutGoalMaxBinding: Binding<Int> {
        Binding(
            get: { workoutGoalRange.upperBound },
            set: { newValue in
                workoutGoalMax = max(newValue, workoutGoalMin + 1)
                clampActiveGoalToRanges()
            }
        )
    }

    private var minuteGoalMinBinding: Binding<Int> {
        Binding(
            get: { minuteGoalRange.lowerBound },
            set: { newValue in
                minuteGoalMin = max(newValue, 1)
                if minuteGoalMax <= minuteGoalMin {
                    minuteGoalMax = minuteGoalMin + 15
                }
                clampActiveGoalToRanges()
            }
        )
    }

    private var minuteGoalMaxBinding: Binding<Int> {
        Binding(
            get: { minuteGoalRange.upperBound },
            set: { newValue in
                minuteGoalMax = max(newValue, minuteGoalMin + 15)
                clampActiveGoalToRanges()
            }
        )
    }

    private var distanceGoalMinBinding: Binding<Double> {
        Binding(
            get: { distanceGoalRange.lowerBound },
            set: { newValue in
                distanceGoalMin = max(newValue, 0.1)
                if distanceGoalMax <= distanceGoalMin {
                    distanceGoalMax = distanceGoalMin + 1
                }
                clampActiveGoalToRanges()
            }
        )
    }

    private var distanceGoalMaxBinding: Binding<Double> {
        Binding(
            get: { distanceGoalRange.upperBound },
            set: { newValue in
                distanceGoalMax = max(newValue, distanceGoalMin + 1)
                clampActiveGoalToRanges()
            }
        )
    }

    private func clampActiveGoalToRanges() {
        goalSetupDraft.workouts = clamp(goalSetupDraft.workouts, to: workoutGoalRange)
        goalSetupDraft.minutes = clamp(goalSetupDraft.minutes, to: minuteGoalRange)
        goalSetupDraft.distance = clamp(goalSetupDraft.distance, to: distanceGoalRange)

        guard var goal = activeGoal else { return }
        goal.workouts = clamp(goal.workouts, to: workoutGoalRange)
        goal.minutes = clamp(goal.minutes, to: minuteGoalRange)
        goal.distance = clamp(goal.distance, to: distanceGoalRange)
        save(goal: goal)
    }

    private func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func save(goal: AnalyticsWorkoutGoal) {
        switch selectedFilter {
        case .all:
            weeklyGoalWorkouts = goal.workouts
            weeklyGoalMinutes = goal.minutes
            weeklyGoalDistance = goal.distance
        case .apple:
            workoutTypeGoals[selectedFilter.goalStorageKey] = goal
            persistWorkoutTypeGoals()
        }
    }

    private func loadWorkoutTypeGoals() {
        guard !analyticsWorkoutTypeGoalsData.isEmpty else {
            workoutTypeGoals = [:]
            return
        }
        workoutTypeGoals = (try? JSONDecoder().decode([String: AnalyticsWorkoutGoal].self, from: analyticsWorkoutTypeGoalsData)) ?? [:]
    }

    private func persistWorkoutTypeGoals() {
        analyticsWorkoutTypeGoalsData = (try? JSONEncoder().encode(workoutTypeGoals)) ?? Data()
    }

    @MainActor
    private func refreshWeeklyRecapSharePayload() {
        let renderer = ImageRenderer(content: weeklyRecapShareSnapshot)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        weeklyRecapSharePayload = WeeklyRecapShareImage(data: data)
        weeklyRecapSharePreview = Image(uiImage: image)
    }

    private var weeklyRecapShareSnapshot: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Weekly Recap", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(weeklyRecapHeadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                shareMetricPill(icon: "figure.run", text: "\(workoutsThisWeek.count) workouts")
                shareMetricPill(icon: "clock.fill", text: "\(weeklyMinutes) min")
                shareMetricPill(icon: "flame.fill", text: "\(currentDailyStreak)d streak")
            }
        }
        .frame(width: shareCardWidth, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.88), Color.blue.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 0.8)
        )
    }

    private var shareCardWidth: CGFloat {
        // Match the in-app card width (horizontal padding of 16 on each side).
        max(UIScreen.main.bounds.width - 32, 280)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }
}

private enum AnalyticsWorkoutFilter: Hashable, Identifiable {
    case all
    case apple(HKWorkoutActivityType)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .apple(let activityType):
            return "apple-\(activityType.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .apple(let activityType):
            return activityType.displayName
        }
    }

    var goalStorageKey: String {
        switch self {
        case .all:
            return "all"
        case .apple(let activityType):
            return "apple-\(activityType.rawValue)"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .apple(let activityType):
            return activityType.systemImage
        }
    }
}

private struct AnalyticsWorkoutGoal: Codable {
    var workouts: Int
    var minutes: Int
    var distance: Double = 10
}

private extension HKWorkoutActivityType {
    var prefersDistanceGoal: Bool {
        switch self {
        case .running, .walking, .cycling, .hiking, .swimming, .wheelchairWalkPace, .wheelchairRunPace:
            return true
        default:
            return false
        }
    }
}

private struct ExercisePR {
    let exerciseName: String
    let topSetWeight: Double
    let estimatedOneRepMax: Double
    let date: Date
}

private struct SmartPROpportunity {
    let exerciseName: String
    let latestTopSet: Double
    let prTopSet: Double
    let progressToPR: Double
}

private struct AdaptiveRecommendation {
    let name: String
    let reason: String
}

private struct SessionGuidanceItem {
    let title: String
    let detail: String
}

private struct WeeklyRecapShareImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { recap in
            recap.data
        }
        .suggestedFileName("ExercisePal-Weekly-Recap")
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, WorkoutExercise.self], inMemory: true)
}
