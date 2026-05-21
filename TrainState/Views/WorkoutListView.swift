import SwiftUI
import SwiftData
import RevenueCatUI
import HealthKit
import UserNotifications
import CoreLocation

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Query(sort: \StrengthWorkoutTemplate.updatedAt, order: .reverse) private var strengthTemplates: [StrengthWorkoutTemplate]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var showingPaywall = false
    @State private var selectedFilter: WorkoutFilter = .all
    @AppStorage("hasSetWeeklyGoal") private var hasSetWeeklyGoal = false
    @AppStorage("hasEnabledWorkoutReminders") private var hasEnabledWorkoutReminders = false
    @AppStorage("hasDismissedFirstSessionChecklist") private var hasDismissedFirstSessionChecklist = false
    @AppStorage("quickLogSheetRequestToken") private var quickLogSheetRequestToken = ""
    @AppStorage("healthKitRecentWorkoutsCache") private var healthKitRecentWorkoutsCacheData: Data = Data()
    @State private var recentHealthKitWorkouts: [HealthKitRecentWorkoutMenuItem] = []
    @State private var isLoadingRecentHealthKitWorkouts = false
    @State private var isImportingHealthKitWorkout = false
    @State private var healthKitImportErrorMessage: String?
    @State private var newlyImportedHealthKitUUIDs: Set<String> = []
    @State private var pendingHealthKitItem: HealthKitRecentWorkoutMenuItem?
    @State private var pendingAttachItem: HealthKitRecentWorkoutMenuItem?
    @State private var showingHealthKitActionSheet = false
    @State private var editingWorkout: Workout?
    @State private var workoutForRoutePreview: Workout?
    @State private var workoutForCategoryAssignment: Workout?
    @State private var workoutForExercisePreview: Workout?
    @State private var workoutPendingDelete: Workout?
    @State private var showingWorkoutDeleteConfirmation = false
    @State private var workoutPendingTemplateSave: Workout?
    @State private var showingSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var selectedCategoriesForAssignment: [WorkoutCategory] = []
    @State private var selectedSubcategoriesForAssignment: [WorkoutSubcategory] = []
    @State private var pendingCategoryAssignmentWorkout: Workout?
    @State private var pendingCategoryAssignmentSaveTask: Task<Void, Never>?
    @State private var lastKnownWorkoutCount = 0
    @State private var successBanner: SuccessBannerModel?
    @State private var bannerDismissTask: Task<Void, Never>?
    @State private var pendingQuickExerciseLogs: [PendingQuickExerciseLog] = []
    @State private var showingQuickLogSheet = false
    @State private var handledQuickLogSheetRequestToken = ""
    private let healthKitImporter = HealthKitRecentWorkoutImporter()

    private var canAddWorkout: Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || workouts.count < PremiumLimits.freeWorkoutLimit
    }

    private var showLimitsCard: Bool {
        purchaseManager.hasCompletedInitialPremiumCheck && !purchaseManager.hasActiveSubscription
    }

    var body: some View {
        NavigationStack {
            workoutListContent
            .listStyle(.insetGrouped)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top) {
                if let successBanner {
                    postLogSuccessBanner(successBanner)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: successBanner)
            .toolbar(content: workoutToolbarContent)
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .sheet(isPresented: $showingQuickLogSheet) {
                WorkoutQuickExerciseLogSheet {
                    refreshQuickExerciseLogs()
                } availableSubcategories: {
                    quickLogExerciseSubcategories
                } availableOptions: {
                    quickLogExerciseOptions
                }
            }
            .sheet(item: $editingWorkout) { workout in
                EditWorkoutView(workout: workout)
            }
            .sheet(item: $workoutForRoutePreview) { workout in
                routePreviewSheet(for: workout)
            }
            .sheet(item: $workoutForCategoryAssignment) { workout in
                CategoryAndSubcategorySelectionView(
                    selectedCategories: $selectedCategoriesForAssignment,
                    selectedSubcategories: $selectedSubcategoriesForAssignment,
                    workoutType: workout.type,
                    appleWorkoutActivityType: workout.appleWorkoutActivityType,
                    lockedSubcategoryIDs: Set((workout.exercises ?? []).compactMap { $0.subcategory?.id })
                )
            }
            .sheet(item: $workoutForExercisePreview) { workout in
                workoutExercisesSheet(for: workout)
            }
            .sheet(isPresented: $showingPaywall) {
                if let offering = purchaseManager.offerings?.current {
                    PaywallView(offering: offering)
                } else {
                    PaywallPlaceholderView(onDismiss: { showingPaywall = false })
                }
            }
            .alert("HealthKit Import", isPresented: healthKitImportAlertBinding) {
                Button("OK", role: .cancel) {
                    healthKitImportErrorMessage = nil
                }
            } message: {
                if let healthKitImportErrorMessage {
                    Text(healthKitImportErrorMessage)
                }
            }
            .alert("Save as Template", isPresented: $showingSaveTemplateAlert) {
                TextField("Template name", text: $templateName)
                Button("Cancel", role: .cancel) {
                    workoutPendingTemplateSave = nil
                    templateName = ""
                }
                Button("Save") {
                    saveWorkoutAsTemplate()
                }
                .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Save this workout's exercises as a reusable strength template.")
            }
            .confirmationDialog(
                "Delete Workout",
                isPresented: $showingWorkoutDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedWorkout()
                }
                Button("Cancel", role: .cancel) {
                    workoutPendingDelete = nil
                }
            } message: {
                Text("This workout will be permanently deleted. This action cannot be undone.")
            }
            .confirmationDialog(
                "Use this Apple Health workout",
                isPresented: $showingHealthKitActionSheet,
                presenting: pendingHealthKitItem
            ) { item in
                if hasAttachableWorkouts(for: item) {
                    Button("Attach to an existing workout") {
                        pendingAttachItem = item
                    }
                }
                Button("Import as new workout") {
                    Task { await importHealthKitWorkout(item) }
                }
                Button("Cancel", role: .cancel) { }
            } message: { item in
                Text(healthKitWorkoutTitle(item))
            }
            .sheet(item: $pendingAttachItem) { item in
                HealthKitAttachTargetPickerView(
                    item: item,
                    workouts: attachableWorkouts(for: item),
                    onSelect: { workout in
                        Task { await attachHealthKitWorkout(item, to: workout) }
                    }
                )
            }
        }
        .onAppear {
            loadCachedRecentHealthKitWorkouts()
            refreshQuickExerciseLogs()
            lastKnownWorkoutCount = workouts.count
            syncReminderPermissionStatus()
            Task { await loadRecentHealthKitWorkouts(showAlerts: false) }
        }
        .onChange(of: workouts.count) { _, newCount in
            if newCount > lastKnownWorkoutCount {
                presentPostLogSuccessBanner()
            }
            lastKnownWorkoutCount = newCount
            normalizeSelectedFilter()
            refreshQuickExerciseLogs()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            QuickExerciseLogStore.attachPendingLogs(to: workouts, in: modelContext)
            refreshQuickExerciseLogs()
        }
        .onChange(of: quickLogSheetRequestToken) { _, _ in
            openQuickLogSheetIfRequested()
        }
        .onChange(of: workoutForCategoryAssignment) { _, newValue in
            if newValue == nil, pendingCategoryAssignmentWorkout != nil {
                pendingCategoryAssignmentSaveTask?.cancel()
                pendingCategoryAssignmentSaveTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    applyWorkoutCategoryAssignment()
                }
            }
        }
    }

    private var workoutListContent: some View {
        List {
            if selectedFilter != .all {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Filtered by \(selectedFilter.title)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Clear") {
                            selectedFilter = .all
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }

            if groupedVisibleWorkouts.isEmpty {
                emptyWorkoutsSection
            }

            if shouldShowTodayQuickLogsSection {
                todayQuickLogsSection
            }

            if showLimitsCard {
                Section("Free Tier") {
                    limitsCard
                }
            }

            if shouldShowFirstSessionChecklist {
                Section("Getting Started") {
                    firstSessionChecklistCard
                }
            }

            ForEach(groupedVisibleWorkouts, id: \.date) { entry in
                workoutSection(for: entry)
            }

            Section {
                rateAppCard
            }
        }
    }

    private var emptyWorkoutsSection: some View {
        Section {
            ContentUnavailableView {
                Label(emptyWorkoutsTitle, systemImage: emptyWorkoutsSystemImage)
            } description: {
                Text(emptyWorkoutsDescription)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private var emptyWorkoutsTitle: String {
        if selectedFilter == .all {
            return "No Workouts"
        }
        return "No \(selectedFilter.title) Workouts"
    }

    private var emptyWorkoutsDescription: String {
        if selectedFilter == .all {
            return "Tap + to log your first workout."
        }
        return "No workouts match the current filter."
    }

    private var emptyWorkoutsSystemImage: String {
        switch selectedFilter {
        case .all:
            return "figure.run"
        case .apple(let activityType):
            return activityType.systemImage
        }
    }

    private var shouldShowTodayQuickLogsSection: Bool {
        selectedFilter == .all && (!todaysPendingQuickLogs.isEmpty || !todaysAttachedQuickExercises.isEmpty)
    }

    private var todayQuickLogsSection: some View {
        Section {
            if !todaysPendingQuickLogs.isEmpty {
                ForEach(todaysPendingQuickLogs) { log in
                    quickLogRow(
                        title: log.exerciseName,
                        detail: log.summary,
                        timestamp: log.loggedAt,
                        systemImage: "tray.and.arrow.down.fill",
                        tint: .orange
                    )
                }
                .onDelete(perform: deleteTodaysPendingQuickLogs)
            }

            if !todaysAttachedQuickExercises.isEmpty {
                ForEach(todaysAttachedQuickExercises, id: \.id) { exercise in
                    quickLogRow(
                        title: exercise.name,
                        detail: attachedExerciseSummary(exercise),
                        timestamp: nil,
                        systemImage: "checkmark.circle.fill",
                        tint: .green
                    )
                }
            }
        } header: {
            Text("Today's Quick Logs")
        } footer: {
            Text(todayQuickLogsFooter)
        }
    }

    private func quickLogRow(
        title: String,
        detail: String,
        timestamp: Date?,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let timestamp {
                Text(timestamp, style: .time)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var todayQuickLogsFooter: String {
        if !todaysPendingQuickLogs.isEmpty && todaysAttachedQuickExercises.isEmpty {
            return "These are queued from the widget and will attach when you create or import a workout for today."
        }
        if todaysPendingQuickLogs.isEmpty {
            return "These quick logs have been attached to today's workout."
        }
        return "Queued logs will attach to today's workout; attached logs are already saved."
    }

    private func workoutSection(for entry: (date: Date, items: [Workout])) -> some View {
        Section(sectionHeaderTitle(for: entry.date)) {
            ForEach(entry.items, id: \.id) { workout in
                workoutRow(for: workout)
            }
        }
    }

    private func workoutRow(for workout: Workout) -> some View {
        NavigationLink {
            WorkoutDetailView(workout: workout)
        } label: {
            WorkoutRowView(workout: workout, showsChevron: false)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingWorkout = workout
            } label: {
                Label("Edit Workout", systemImage: "pencil")
            }

            if canSaveAsStrengthTemplate(workout) {
                Button {
                    workoutPendingTemplateSave = workout
                    templateName = defaultTemplateName(for: workout)
                    showingSaveTemplateAlert = true
                } label: {
                    Label("Save as Template", systemImage: "square.and.arrow.down")
                }
            }

            if hasRoute(workout) {
                Button {
                    workoutForRoutePreview = workout
                } label: {
                    Label("View Route", systemImage: "map")
                }
            }

            Button {
                prepareCategoryAssignment(for: workout)
            } label: {
                Label("Assign Categories", systemImage: "tag")
            }

            if hasExercises(workout) {
                Button {
                    workoutForExercisePreview = workout
                } label: {
                    Label("View Exercises", systemImage: "list.bullet")
                }
            }

            Button {
                openWorkoutInCalendar(workout)
            } label: {
                Label("Open in Calendar", systemImage: "calendar")
            }

            Button(role: .destructive) {
                workoutPendingDelete = workout
                showingWorkoutDeleteConfirmation = true
            } label: {
                Label("Delete Workout", systemImage: "trash")
            }
        }
    }

    private var todaysPendingQuickLogs: [PendingQuickExerciseLog] {
        let calendar = Calendar.current
        return pendingQuickExerciseLogs
            .filter { calendar.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private var todaysAttachedQuickExercises: [WorkoutExercise] {
        todayWorkouts
            .flatMap { $0.exercises ?? [] }
            .filter { $0.notes?.contains("Logged from widget") == true }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var todayWorkouts: [Workout] {
        workouts
            .filter { Calendar.current.isDateInToday($0.startDate) }
            .sorted { $0.startDate > $1.startDate }
    }

    private var quickLogExerciseSubcategories: [WorkoutSubcategory] {
        subcategories
            .filter { subcategory in
                guard let category = subcategory.category else { return false }
                return category.matches(
                    appleWorkoutActivityType: HKWorkoutActivityType.traditionalStrengthTraining,
                    fallbackWorkoutType: .strength
                )
            }
            .sorted { $0.name < $1.name }
    }

    private var quickLogExerciseOptions: [ExerciseQuickAddOption] {
        var options: [ExerciseQuickAddOption] = []
        for subcategory in quickLogExerciseSubcategories {
            let templates = exerciseTemplates
                .filter { $0.subcategory?.id == subcategory.id }
                .sorted { $0.orderIndex < $1.orderIndex }
            if templates.isEmpty {
                options.append(ExerciseQuickAddOption(name: subcategory.name, subcategoryID: subcategory.id))
            } else {
                options.append(contentsOf: templates.map {
                    ExerciseQuickAddOption(name: $0.name, subcategoryID: subcategory.id)
                })
            }
        }
        return options
    }

    private func refreshQuickExerciseLogs() {
        pendingQuickExerciseLogs = QuickExerciseLogStore.pendingLogs()
    }

    private func openQuickLogSheetIfRequested() {
        guard !quickLogSheetRequestToken.isEmpty,
              quickLogSheetRequestToken != handledQuickLogSheetRequestToken else {
            return
        }
        handledQuickLogSheetRequestToken = quickLogSheetRequestToken
        quickLogSheetRequestToken = ""
        showingQuickLogSheet = true
    }

    private func deleteTodaysPendingQuickLogs(at offsets: IndexSet) {
        let idsToDelete = Set(offsets.map { todaysPendingQuickLogs[$0].id })
        let remainingLogs = pendingQuickExerciseLogs.filter { !idsToDelete.contains($0.id) }
        QuickExerciseLogStore.savePendingLogs(remainingLogs)
        pendingQuickExerciseLogs = remainingLogs
    }

    private func attachedExerciseSummary(_ exercise: WorkoutExercise) -> String {
        var parts: [String] = []
        if let sets = exercise.sets, sets > 0 {
            parts.append("\(sets) set\(sets == 1 ? "" : "s")")
        }
        if let reps = exercise.reps, reps > 0 {
            parts.append("\(reps) reps")
        }
        if let weight = exercise.weight, weight > 0 {
            parts.append("\(ExerciseLogEntry.displayWeight(weight)) kg")
        }
        return parts.isEmpty ? "Attached to today's workout" : parts.joined(separator: " - ")
    }

    @ToolbarContentBuilder
    private func workoutToolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                showingQuickLogSheet = true
            } label: {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Quick Log")
            filterMenu
            healthKitMenu
            addWorkoutButton
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(availableFilters, id: \.self) { filter in
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
            Image(systemName: selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private var availableFilters: [WorkoutFilter] {
        let savedActivityTypes = Set(workouts.map(\.resolvedAppleWorkoutActivityType))
        let activityFilters = savedActivityTypes
            .sorted { $0.displayName < $1.displayName }
            .map { WorkoutFilter.apple($0) }
        return [.all] + activityFilters
    }

    private var healthKitMenu: some View {
        Menu {
            Section("HealthKit") {
                Button {
                    Task { await loadRecentHealthKitWorkouts() }
                } label: {
                    Label("Refresh Recent Workouts", systemImage: "arrow.clockwise")
                }
                .menuActionDismissBehavior(.disabled)

                Button {
                    Task { await importAllAvailableHealthKitWorkouts() }
                } label: {
                    Label(
                        bulkImportButtonTitle,
                        systemImage: "square.and.arrow.down.on.square"
                    )
                }
                .disabled(isImportingHealthKitWorkout || availableHealthKitImportCandidates.isEmpty)
                .menuActionDismissBehavior(.disabled)
            }

            healthKitRecentWorkoutsSection
        } label: {
            Image(systemName: "heart.text.square")
        }
        .disabled(isImportingHealthKitWorkout)
    }

    @ViewBuilder
    private var healthKitRecentWorkoutsSection: some View {
        if isLoadingRecentHealthKitWorkouts {
            Section {
                Label("Loading...", systemImage: "hourglass")
            }
        } else if recentHealthKitWorkouts.isEmpty {
            Section {
                Text("No recent workouts available for import.")
            }
        } else {
            Section("Recent Workouts") {
                ForEach(recentHealthKitWorkouts) { candidate in
                    healthKitCandidateButton(for: candidate)
                }
            }
        }
    }

    private func healthKitCandidateButton(for candidate: HealthKitRecentWorkoutMenuItem) -> some View {
        let isImported = importedHealthKitUUIDs.contains(candidate.hkUUID) || newlyImportedHealthKitUUIDs.contains(candidate.hkUUID)

        return Button {
            handleHealthKitCandidateSelection(candidate)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: candidate.activityType.systemImage)
                    .foregroundStyle(candidate.activityType.mappedWorkoutType.tintColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(healthKitWorkoutTitle(candidate))
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(healthKitWorkoutSubtitle(candidate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isImported {
                    Label("Imported", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .disabled(isImported)
    }

    private func handleHealthKitCandidateSelection(_ candidate: HealthKitRecentWorkoutMenuItem) {
        guard hasAttachableWorkouts(for: candidate) else {
            pendingHealthKitItem = nil
            pendingAttachItem = nil
            Task { await importHealthKitWorkout(candidate) }
            return
        }

        pendingHealthKitItem = candidate
        showingHealthKitActionSheet = true
    }

    private var addWorkoutButton: some View {
        Button {
            if canAddWorkout {
                showingAddWorkout = true
            } else {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showingPaywall = true
                }
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private var healthKitImportAlertBinding: Binding<Bool> {
        Binding(
            get: { healthKitImportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    healthKitImportErrorMessage = nil
                }
            }
        )
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                limitRow(
                    label: "Workouts",
                    used: workouts.count,
                    limit: PremiumLimits.freeWorkoutLimit
                )
                limitRow(
                    label: "Categories",
                    used: categories.count,
                    limit: PremiumLimits.freeCategoryLimit
                )
                Text("2 subcategories per category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showingPaywall = true
                }
            } label: {
                Label("Upgrade to Premium", systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func deleteSelectedWorkout() {
        guard let workoutPendingDelete else { return }
        modelContext.delete(workoutPendingDelete)
        do {
            try modelContext.save()
        } catch {
            healthKitImportErrorMessage = "Failed to delete workout. Please try again."
        }
        self.workoutPendingDelete = nil
    }

    private func hasRoute(_ workout: Workout) -> Bool {
        guard let route = workout.route?.decodedRoute else { return false }
        return !route.isEmpty
    }

    private func hasExercises(_ workout: Workout) -> Bool {
        !(workout.exercises?.isEmpty ?? true)
    }

    private func canSaveAsStrengthTemplate(_ workout: Workout) -> Bool {
        workout.type == .strength && !(workout.exercises?.isEmpty ?? true)
    }

    private func prepareCategoryAssignment(for workout: Workout) {
        pendingCategoryAssignmentSaveTask?.cancel()
        pendingCategoryAssignmentWorkout = workout
        selectedCategoriesForAssignment = workout.categories ?? []
        selectedSubcategoriesForAssignment = workout.subcategories ?? []
        workoutForCategoryAssignment = workout
    }

    private func applyWorkoutCategoryAssignment() {
        guard let workout = pendingCategoryAssignmentWorkout else { return }
        workout.categories = selectedCategoriesForAssignment
        workout.subcategories = selectedSubcategoriesForAssignment
        try? modelContext.save()
        pendingCategoryAssignmentWorkout = nil
        workoutForCategoryAssignment = nil
    }

    private func openWorkoutInCalendar(_ workout: Workout) {
        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        let timeInterval = workout.startDate.timeIntervalSince(referenceDate)
        guard let url = URL(string: "calshow:\(timeInterval)") else { return }
        openURL(url)
    }

    private func defaultTemplateName(for workout: Workout) -> String {
        let base = "Strength \(workout.startDate.formatted(date: .abbreviated, time: .omitted))"
        let existingNames = Set(strengthTemplates.map { $0.name.lowercased() })
        if !existingNames.contains(base.lowercased()) {
            return base
        }

        var suffix = 2
        while existingNames.contains("\(base) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    private func saveWorkoutAsTemplate() {
        guard let workout = workoutPendingTemplateSave else { return }

        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let sortedWorkoutExercises = (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let templateExercises = sortedWorkoutExercises.enumerated().map { index, exercise in
            StrengthWorkoutTemplateExercise(
                name: exercise.name,
                orderIndex: index,
                sets: exercise.sets,
                reps: exercise.reps,
                weight: exercise.weight,
                subcategoryID: exercise.subcategory?.id
            )
        }

        guard !templateExercises.isEmpty else { return }

        if let existing = strengthTemplates.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            existing.name = name
            existing.mainCategoryRawValue = workout.type.rawValue
            existing.appleWorkoutActivityType = workout.appleWorkoutActivityType ?? workout.type.defaultAppleWorkoutActivityType
            existing.updatedAt = Date()
            existing.exercises = templateExercises
        } else {
            let template = StrengthWorkoutTemplate(
                name: name,
                mainCategoryRawValue: workout.type.rawValue,
                appleWorkoutActivityType: workout.appleWorkoutActivityType ?? workout.type.defaultAppleWorkoutActivityType,
                exercises: templateExercises
            )
            modelContext.insert(template)
        }

        try? modelContext.save()
        workoutPendingTemplateSave = nil
        templateName = ""
    }

    @ViewBuilder
    private func routePreviewSheet(for workout: Workout) -> some View {
        if let route = workout.route?.decodedRoute, !route.isEmpty {
            RouteMapSheetView(route: route)
        } else {
            NavigationStack {
                ContentUnavailableView("No Route", systemImage: "map", description: Text("This workout does not have route data available."))
                    .navigationTitle("Workout Route")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                workoutForRoutePreview = nil
                            }
                        }
                    }
            }
        }
    }

    private func workoutExercisesSheet(for workout: Workout) -> some View {
        let exercises = (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }

        return NavigationStack {
            List {
                if exercises.isEmpty {
                    ContentUnavailableView("No Exercises", systemImage: "list.bullet", description: Text("This workout does not have any logged exercises."))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(exercises, id: \.id) { exercise in
                        ExerciseCardView(exercise: exercise, showChevron: false, colorScheme: colorScheme)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        workoutForExercisePreview = nil
                    }
                }
            }
        }
    }

    private var rateAppCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enjoying Exercise Pal?")
                .font(.headline)
            Text("Leave a review on the App Store.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                openAppStoreReviewPage()
            } label: {
                Label("Rate Exercise Pal", systemImage: "star.bubble.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var shouldShowFirstSessionChecklist: Bool {
        !hasDismissedFirstSessionChecklist && !isFirstSessionChecklistCompleted
    }

    private var isFirstSessionChecklistCompleted: Bool {
        hasLoggedFirstWorkout && hasSetWeeklyGoal && hasEnabledWorkoutReminders
    }

    private var hasLoggedFirstWorkout: Bool {
        !workouts.isEmpty
    }

    private var firstSessionChecklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("First Session Checklist")
                    .font(.headline)
                Spacer()
                Button("Hide") {
                    hasDismissedFirstSessionChecklist = true
                }
                .buttonStyle(.borderless)
            }

            checklistRow(
                title: "Log your first workout",
                isDone: hasLoggedFirstWorkout
            )
            checklistRow(
                title: "Set your weekly goal",
                isDone: hasSetWeeklyGoal
            )
            HStack(spacing: 8) {
                checklistRow(
                    title: "Enable reminders",
                    isDone: hasEnabledWorkoutReminders
                )
                if !hasEnabledWorkoutReminders {
                    Button("Enable") {
                        requestReminderPermission()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func checklistRow(title: String, isDone: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? Color.green : Color.secondary)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func limitRow(label: String, used: Int, limit: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(used)/\(limit)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(used >= limit ? .red : .primary)
        }
    }

    private var filteredWorkouts: [Workout] {
        if selectedFilter == .all {
            return workouts
        }
        guard let filterActivityType = selectedFilter.activityType else { return workouts }
        return workouts.filter { $0.resolvedAppleWorkoutActivityType == filterActivityType }
    }

    private func normalizeSelectedFilter() {
        if !availableFilters.contains(selectedFilter) {
            selectedFilter = .all
        }
    }

    private var groupedVisibleWorkouts: [(date: Date, items: [Workout])] {
        let grouped = Dictionary(grouping: filteredWorkouts) { Calendar.current.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    private func sectionHeaderTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }

    private var importedHealthKitUUIDs: Set<String> {
        Set(workouts.compactMap(\.hkUUID))
    }

    private var availableHealthKitImportCandidates: [HealthKitRecentWorkoutMenuItem] {
        recentHealthKitWorkouts.filter {
            !importedHealthKitUUIDs.contains($0.hkUUID) &&
            !newlyImportedHealthKitUUIDs.contains($0.hkUUID)
        }
    }

    private var bulkImportButtonTitle: String {
        let count = availableHealthKitImportCandidates.count
        if count == 0 {
            return "Import All Recent Workouts"
        }
        return "Import All (\(count))"
    }

    @MainActor
    private func loadRecentHealthKitWorkouts(showAlerts: Bool = true) async {
        guard !isLoadingRecentHealthKitWorkouts else { return }
        isLoadingRecentHealthKitWorkouts = true
        defer { isLoadingRecentHealthKitWorkouts = false }

        do {
            recentHealthKitWorkouts = try await healthKitImporter.fetchRecentWorkouts(limit: 30)
            saveRecentHealthKitWorkoutsCache(recentHealthKitWorkouts)
        } catch {
            if showAlerts {
                healthKitImportErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func importHealthKitWorkout(_ candidate: HealthKitRecentWorkoutMenuItem) async {
        guard !isImportingHealthKitWorkout else { return }
        if importedHealthKitUUIDs.contains(candidate.hkUUID) || newlyImportedHealthKitUUIDs.contains(candidate.hkUUID) {
            return
        }
        isImportingHealthKitWorkout = true
        defer { isImportingHealthKitWorkout = false }

        do {
            try await healthKitImporter.importWorkout(candidate, into: modelContext)
            newlyImportedHealthKitUUIDs.insert(candidate.hkUUID)
        } catch {
            healthKitImportErrorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func importAllAvailableHealthKitWorkouts() async {
        guard !isImportingHealthKitWorkout else { return }

        let candidates = availableHealthKitImportCandidates
        guard !candidates.isEmpty else { return }

        isImportingHealthKitWorkout = true
        defer { isImportingHealthKitWorkout = false }

        do {
            try await healthKitImporter.importWorkoutsBatch(candidates, into: modelContext)
            newlyImportedHealthKitUUIDs.formUnion(candidates.map(\.hkUUID))
        } catch {
            healthKitImportErrorMessage = "Bulk import failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func attachHealthKitWorkout(_ candidate: HealthKitRecentWorkoutMenuItem, to workout: Workout) async {
        guard !isImportingHealthKitWorkout else { return }
        if importedHealthKitUUIDs.contains(candidate.hkUUID) || newlyImportedHealthKitUUIDs.contains(candidate.hkUUID) {
            return
        }
        isImportingHealthKitWorkout = true
        defer { isImportingHealthKitWorkout = false }

        do {
            try await healthKitImporter.attachWorkout(candidate, to: workout, in: modelContext)
            newlyImportedHealthKitUUIDs.insert(candidate.hkUUID)
        } catch {
            healthKitImportErrorMessage = "Attach failed: \(error.localizedDescription)"
        }
    }

    private func attachableWorkouts(for item: HealthKitRecentWorkoutMenuItem) -> [Workout] {
        let calendar = Calendar.current
        return workouts.filter { calendar.isDate($0.startDate, inSameDayAs: item.startDate) }
    }

    private func hasAttachableWorkouts(for item: HealthKitRecentWorkoutMenuItem) -> Bool {
        !attachableWorkouts(for: item).isEmpty
    }

    private func healthKitWorkoutTitle(_ candidate: HealthKitRecentWorkoutMenuItem) -> String {
        return [
            candidate.activityType.displayName(locationType: candidate.locationType),
            candidate.startDate.formatted(date: .omitted, time: .shortened),
            relativeDateCompactLabel(for: candidate.startDate)
        ].joined(separator: "\n")
    }

    private func healthKitWorkoutSubtitle(_ candidate: HealthKitRecentWorkoutMenuItem) -> String {
        var parts: [String] = []
        if let distance = candidate.distanceKilometers, distance > 0 {
            parts.append(String(format: "%.1f km", distance))
        }
        parts.append(candidate.sourceName)
        return parts.joined(separator: " · ")
    }

    private func relativeDateCompactLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func loadCachedRecentHealthKitWorkouts() {
        guard !healthKitRecentWorkoutsCacheData.isEmpty else { return }
        guard recentHealthKitWorkouts.isEmpty else { return }

        do {
            recentHealthKitWorkouts = try JSONDecoder().decode(
                [HealthKitRecentWorkoutMenuItem].self,
                from: healthKitRecentWorkoutsCacheData
            )
        } catch {
            healthKitRecentWorkoutsCacheData = Data()
        }
    }

    private func saveRecentHealthKitWorkoutsCache(_ items: [HealthKitRecentWorkoutMenuItem]) {
        do {
            healthKitRecentWorkoutsCacheData = try JSONEncoder().encode(items)
        } catch {
            // Ignore cache writes if encoding fails.
        }
    }

    private func openAppStoreReviewPage() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id6747159475?action=write-review") else { return }
        openURL(url)
    }

    private func requestReminderPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    hasEnabledWorkoutReminders = settings.authorizationStatus == .authorized
                }
            }
        }
    }

    private func syncReminderPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                hasEnabledWorkoutReminders = settings.authorizationStatus == .authorized
            }
        }
    }

    private func presentPostLogSuccessBanner() {
        let weeklyCount = workoutsThisWeekCount
        let streakDays = workoutDayStreak
        successBanner = SuccessBannerModel(
            title: "Workout Logged",
            subtitle: "Nice work. Keep the momentum going.",
            weeklyCount: weeklyCount,
            streakDays: streakDays
        )
        bannerDismissTask?.cancel()
        bannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            await MainActor.run {
                successBanner = nil
            }
        }
    }

    private func postLogSuccessBanner(_ banner: SuccessBannerModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .orange)
                .symbolEffect(.pulse, options: .nonRepeating)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(banner.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(banner.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    metricPill(icon: "calendar", text: "\(banner.weeklyCount) this week")
                    metricPill(icon: "flame.fill", text: "\(banner.streakDays)-day streak")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 3)
    }

    private func metricPill(icon: String, text: String) -> some View {
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

    private var workoutsThisWeekCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return 0
        }
        return workouts.filter { $0.startDate >= weekStart && $0.startDate <= now }.count
    }

    private var workoutDayStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        while uniqueDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return max(streak, 1)
    }
}

private struct SuccessBannerModel: Equatable {
    let title: String
    let subtitle: String
    let weeklyCount: Int
    let streakDays: Int
}

// MARK: - HealthKit Attach Target Picker
private struct HealthKitAttachTargetPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let item: HealthKitRecentWorkoutMenuItem
    let workouts: [Workout]
    let onSelect: (Workout) -> Void

    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    Text("No workouts found for this day. Log a workout first, then attach this Apple Health session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 8)
                } else {
                    Section(header: Text("Workouts on \(item.startDate.formatted(date: .abbreviated, time: .omitted))")) {
                        ForEach(workouts, id: \.id) { workout in
                            Button {
                                onSelect(workout)
                                dismiss()
                            } label: {
                                WorkoutRowView(workout: workout)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach to Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct WorkoutQuickExerciseLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: ExerciseLogEntry
    @State private var didSave = false
    let onSave: () -> Void
    let availableSubcategories: [WorkoutSubcategory]
    let availableOptions: [ExerciseQuickAddOption]

    init(
        onSave: @escaping () -> Void,
        availableSubcategories: () -> [WorkoutSubcategory],
        availableOptions: () -> [ExerciseQuickAddOption]
    ) {
        self.onSave = onSave
        self.availableSubcategories = availableSubcategories()
        self.availableOptions = availableOptions()

        let firstSubcategoryID = self.availableSubcategories.first?.id
        _entry = State(initialValue: ExerciseLogEntry(subcategoryID: firstSubcategoryID))
    }

    var body: some View {
        ExerciseEditorSheetView(
            entry: $entry,
            availableSubcategories: availableSubcategories,
            availableOptions: availableOptions,
            onDelete: {
                entry = ExerciseLogEntry(subcategoryID: availableSubcategories.first?.id)
            },
            quickLogSaveAction: {
                saveQuickLog()
            },
            mode: .workout
        )
    }

    private func saveQuickLog() {
        guard !entry.trimmedName.isEmpty, !didSave else { return }
        let log = PendingQuickExerciseLog(
            id: UUID(),
            exerciseName: entry.trimmedName,
            loggedAt: Date(),
            sets: entry.effectiveSetCount ?? 1,
            reps: entry.effectiveReps ?? 0,
            weight: entry.effectiveWeight
        )
        QuickExerciseLogStore.appendPendingLog(log)
        onSave()
        didSave = true
        entry = ExerciseLogEntry(subcategoryID: availableSubcategories.first?.id)
        dismiss()
    }
}

struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
        let context = container.mainContext
        let calendar = Calendar.current

        let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
        let pull = WorkoutCategory(name: "Pull", color: "#4ECDC4", workoutType: .strength)
        let legs = WorkoutCategory(name: "Legs", color: "#45B7D1", workoutType: .strength)
        let upper = WorkoutCategory(name: "Upper Body", color: "#96CEB4", workoutType: .strength)
        let endurance = WorkoutCategory(name: "Endurance", color: "#FFEAA7", workoutType: .running)
        context.insert(push)
        context.insert(pull)
        context.insert(legs)
        context.insert(upper)
        context.insert(endurance)

        let benchPress = WorkoutSubcategory(name: "Bench Press", category: push)
        context.insert(benchPress)

        let squat = WorkoutSubcategory(name: "Squat", category: legs)
        context.insert(squat)

        let tempo = WorkoutSubcategory(name: "Tempo", category: endurance)
        context.insert(tempo)

        func addWorkout(type: WorkoutType, daysAgo: Int, durationMinutes: Double, distance: Double? = nil, categories: [WorkoutCategory] = [], subcategories: [WorkoutSubcategory] = []) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let workout = Workout(type: type, startDate: date, duration: durationMinutes * 60, distance: distance, categories: categories.isEmpty ? nil : categories, subcategories: subcategories.isEmpty ? nil : subcategories)
            context.insert(workout)
        }

        let longNameWorkout = Workout(
            type: .strength,
            startDate: Date(),
            duration: 71 * 60,
            distance: nil,
            hkActivityTypeRaw: Int(HKWorkoutActivityType.traditionalStrengthTraining.rawValue)
        )
        context.insert(longNameWorkout)

        addWorkout(type: .running, daysAgo: 0, durationMinutes: 45, distance: 6.2, categories: [endurance], subcategories: [tempo])
        addWorkout(type: .strength, daysAgo: 0, durationMinutes: 60, categories: [push, pull], subcategories: [benchPress])
        addWorkout(type: .yoga, daysAgo: 1, durationMinutes: 30)
        addWorkout(type: .cycling, daysAgo: 3, durationMinutes: 50, distance: 18.4)
        addWorkout(type: .strength, daysAgo: 2, durationMinutes: 45, categories: [legs], subcategories: [squat])
        addWorkout(type: .strength, daysAgo: 4, durationMinutes: 50, categories: [upper])

        return NavigationStack {
            WorkoutListView()
        }
        .modelContainer(container)
    }
}
