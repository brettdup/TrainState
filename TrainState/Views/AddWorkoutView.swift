import SwiftUI
import SwiftData
import HealthKit
import CoreLocation

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @AppStorage("reviewPromptLoggedWorkoutCount") private var reviewPromptLoggedWorkoutCount = 0
    @AppStorage("hasShownWorkoutReviewPrompt") private var hasShownWorkoutReviewPrompt = false
    @Query private var workouts: [Workout]
    @Query(sort: \WorkoutSubcategory.name) private var allSubcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Query(sort: \StrengthWorkoutTemplate.updatedAt, order: .reverse) private var strengthTemplates: [StrengthWorkoutTemplate]
    @Query(sort: \WorkoutRoute.updatedAt, order: .reverse) private var savedWorkoutRoutes: [WorkoutRoute]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var type: WorkoutType = .other
    @State private var selectedAppleWorkout = AppleWorkoutSelection(
        activityType: WorkoutType.other.defaultAppleWorkoutActivityType,
        locationType: nil
    )
    @State private var date = Date()
    @State private var durationMinutes = 30.0
    @State private var distanceKilometers = 0.0
    @State private var workoutRating: Double?
    @State private var notes = ""
    @State private var exerciseEntries: [ExerciseLogEntry] = []
    @State private var showingWorkoutSession = false
    @State private var sessionStartsWithTimer = true
    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var showingPaywall = false
    @State private var isSaving = false
    @State private var hasAppliedSuggestedType = false
    @State private var showingTemplateLibrary = false
    @State private var showingSaveTemplateAlert = false
    @State private var showingDuplicateTypeAlert = false
    @State private var showingAdvancedFields = false
    @State private var showingDiscardChangesAlert = false
    @State private var showingRoutePlanner = false
    @State private var showingSavedRoutePicker = false
    @State private var plannedRoute: [CLLocation] = []
    @State private var plannedRouteWaypoints: [CLLocation] = []
    @State private var plannedRouteName: String?
    @State private var pendingWorkoutToSave: Workout?
    @State private var pendingTemplateEntries: [ExerciseLogEntry]?
    @State private var newTemplateName = ""
    @State private var activeTemplateID: UUID?
    @State private var showingExercisePicker = false
    private let reviewPromptWorkoutThreshold = 3
    private let quickLogPresets: [(title: String, type: WorkoutType, durationMinutes: Double, distanceKilometers: Double?)] = [
        ("Strength 45m", .strength, 45, nil),
        ("Run 30m", .running, 30, 5.0),
        ("Cycle 45m", .cycling, 45, 18.0),
        ("Yoga 20m", .yoga, 20, nil)
    ]

    private let quickDurations: [Double] = [15, 30, 45, 60, 90, 120]
    private var durationBinding: Binding<Double> {
        Binding(
            get: { durationMinutes },
            set: { durationMinutes = min(max($0, 0), 600) }
        )
    }
    private var distanceBinding: Binding<Double> {
        Binding(
            get: { distanceKilometers },
            set: { distanceKilometers = min(max($0, 0), 200) }
        )
    }
    private var workoutRatingBinding: Binding<Double> {
        Binding(
            get: { workoutRating ?? 5.0 },
            set: { workoutRating = min(max($0, 0), 10) }
        )
    }
    private var canAddWorkout: Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || workouts.count < PremiumLimits.freeWorkoutLimit
    }
    private var suggestedWorkoutType: WorkoutType? {
        guard !workouts.isEmpty else { return nil }

        var stats: [WorkoutType: (count: Int, latest: Date)] = [:]
        for workout in workouts {
            let current = stats[workout.type] ?? (count: 0, latest: .distantPast)
            stats[workout.type] = (
                count: current.count + 1,
                latest: max(current.latest, workout.startDate)
            )
        }

        return stats.max { lhs, rhs in
            if lhs.value.count != rhs.value.count {
                return lhs.value.count < rhs.value.count
            }
            return lhs.value.latest < rhs.value.latest
        }?.key
    }
    private var showsDistance: Bool {
        [.running, .cycling, .swimming].contains(type)
    }
    private var canPlanRoute: Bool {
        [.running, .cycling].contains(type)
    }
    private var reusableRoutes: [WorkoutRoute] {
        savedWorkoutRoutes.filter { $0.workout == nil && !($0.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) && ($0.decodedRoute?.count ?? 0) > 1 }
    }
    private var appleWorkoutActivityType: HKWorkoutActivityType { selectedAppleWorkout.activityType }
    private var appleWorkoutLocationType: HKWorkoutSessionLocationType? { selectedAppleWorkout.locationType }
    private var appleWorkoutActivityOptions: [AppleWorkoutSelection] { WorkoutType.other.appleWorkoutActivityOptions }
    private var isStrengthSessionType: Bool {
        type == .strength
    }
    private var availableExerciseSubcategories: [WorkoutSubcategory] {
        allSubcategories.filter { subcategory in
            guard let category = subcategory.category else { return false }
            return category.matches(
                appleWorkoutActivityType: appleWorkoutActivityType,
                fallbackWorkoutType: type
            )
        }
    }
    private var quickAddOptions: [ExerciseQuickAddOption] {
        var options: [ExerciseQuickAddOption] = []
        for subcategory in availableExerciseSubcategories {
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
    private var trackedExerciseCount: Int {
        exerciseEntries.filter { !$0.trimmedName.isEmpty }.count
    }
    private var totalPlannedSets: Int {
        exerciseEntries.reduce(0) { $0 + $1.setEntries.count }
    }
    private var totalCompletedSets: Int {
        exerciseEntries.reduce(0) { $0 + $1.completedSetCount }
    }
    private var activeTemplateName: String? {
        guard let activeTemplateID else { return nil }
        return strengthTemplates.first(where: { $0.id == activeTemplateID })?.name
    }
    private var quickTemplateCandidates: [StrengthWorkoutTemplate] {
        Array(strengthTemplates.prefix(3))
    }
    private var completedExerciseDetailsCount: Int {
        exerciseEntries.filter {
            !$0.trimmedName.isEmpty &&
            $0.sets != nil &&
            $0.reps != nil &&
            $0.weight != nil
        }.count
    }
    private var suggestedQuickAddOptions: [ExerciseQuickAddOption] {
        var seen: Set<String> = []
        let existing = Set(
            exerciseEntries
                .map(\.trimmedName)
                .filter { !$0.isEmpty }
                .map { $0.lowercased() }
        )

        return quickAddOptions.compactMap { option in
            let key = "\(option.subcategoryID.uuidString)-\(option.name.lowercased())"
            guard !seen.contains(key), !existing.contains(option.name.lowercased()) else { return nil }
            seen.insert(key)
            return option
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                quickLogCard
                appleWorkoutTypeCard
                dateCard
                if isStrengthSessionType {
                    strengthTemplatesCard
                    durationCard
                    strengthLiveSessionCard
                } else {
                    durationCard
                }
                if showsDistance { distanceCard }
                if canPlanRoute { routePlannerCard }
                exercisesCard
                advancedSectionCard
                if showingAdvancedFields {
                    ratingCard
                    notesCard
                }
                Section {
                    EmptyView()
                } footer: {
                    saveButton
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { handleCancelTapped() }
                }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            UnifiedExercisePickerView(
                subcategories: availableExerciseSubcategories,
                exerciseOptions: quickAddOptions,
                existingExerciseNames: Set(exerciseEntries.map { $0.trimmedName.lowercased() }),
                onSelect: { selected in
                    for option in selected {
                        addExercise(from: option)
                    }
                },
                onCreateCustom: { name, subcategoryID in
                    saveExerciseTemplateIfNeeded(name: name, subcategoryID: subcategoryID)
                    exerciseEntries.append(ExerciseLogEntry(
                        name: name,
                        subcategoryID: subcategoryID
                    ))
                },
                tintColor: type.tintColor
            )
        }
        .sheet(isPresented: $showingPaywall) {
            CustomPaywallView()
        }
        .sheet(item: $activeExerciseSelection) { selection in
            if let index = exerciseEntries.firstIndex(where: { $0.id == selection.id }) {
                ExerciseEditorSheetView(
                    entry: $exerciseEntries[index],
                    availableSubcategories: availableExerciseSubcategories,
                    availableOptions: quickAddOptions,
                    onDelete: {
                        exerciseEntries.removeAll { $0.id == selection.id }
                    }
                )
            } else {
                EmptyView()
            }
        }
        .alert("Workout Type Already Logged", isPresented: $showingDuplicateTypeAlert) {
            Button("Cancel", role: .cancel) {
                pendingWorkoutToSave = nil
                pendingTemplateEntries = nil
                isSaving = false
            }
            Button("Save Anyway") {
                guard let workout = pendingWorkoutToSave else { return }
                performSave(workout, persistTemplatesFrom: pendingTemplateEntries)
                pendingWorkoutToSave = nil
                pendingTemplateEntries = nil
            }
        } message: {
            if let pendingWorkoutToSave {
                Text("A \(pendingWorkoutToSave.primaryWorkoutDisplayName) workout already exists for \(pendingWorkoutToSave.startDate.formatted(date: .abbreviated, time: .omitted)).")
            } else {
                Text("A workout of this type already exists for this day.")
            }
        }
        .alert("Discard changes?", isPresented: $showingDiscardChangesAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("You have unsaved changes.")
        }
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(
                typeTintColor: type.tintColor,
                availableSubcategories: availableExerciseSubcategories,
                quickAddOptions: quickAddOptions,
                initialEntries: exerciseEntries,
                configuration: WorkoutSessionConfiguration(
                    isTimerRunning: sessionStartsWithTimer,
                    sessionStart: date,
                    title: "Workout"
                )
            ) { completedEntries, startedAt, duration in
                exerciseEntries = completedEntries
                date = startedAt
                let resolvedDuration = duration > 0 ? duration : durationMinutes * 60
                durationMinutes = resolvedDuration / 60.0
                saveStrengthWorkout(startDate: startedAt, duration: resolvedDuration, entries: completedEntries)
            } onCancel: { draftEntries in
                exerciseEntries = draftEntries
            }
        }
        .sheet(isPresented: $showingTemplateLibrary) {
            templateLibrarySheet
        }
        .sheet(isPresented: $showingRoutePlanner) {
            RoutePlannerSheetView(route: plannedRoute, waypoints: plannedRouteWaypoints.isEmpty ? nil : plannedRouteWaypoints, tintColor: type.tintColor) { route, waypoints in
                plannedRoute = route
                plannedRouteWaypoints = waypoints
                plannedRouteName = nil
                if route.count > 1 {
                    distanceKilometers = route.routeDistanceKilometers
                }
            }
        }
        .sheet(isPresented: $showingSavedRoutePicker) {
            SavedRoutePickerView(routes: reusableRoutes, tintColor: type.tintColor) { route in
                guard let locations = route.decodedRoute else { return }
                plannedRoute = locations
                plannedRouteWaypoints = route.decodedWaypoints ?? locations
                plannedRouteName = route.name
                distanceKilometers = locations.routeDistanceKilometers
            }
        }
        .alert("Save Strength Template", isPresented: $showingSaveTemplateAlert) {
            TextField("Template name", text: $newTemplateName)
            Button("Cancel", role: .cancel) {
                newTemplateName = ""
            }
            Button("Save") {
                saveStrengthTemplate(named: newTemplateName, from: exerciseEntries)
                newTemplateName = ""
            }
            .disabled(!canSaveCurrentEntriesAsTemplate || newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Save your current strength exercise list as a reusable template.")
        }
        .onChange(of: type) { _, _ in
            let allowedIDs = Set(availableExerciseSubcategories.map(\.id))
            exerciseEntries = exerciseEntries.map {
                var entry = $0
                if let id = entry.subcategoryID, !allowedIDs.contains(id) {
                    entry.subcategoryID = nil
                }
                return entry
            }
            if type != .strength {
                activeTemplateID = nil
            }
            if !canPlanRoute {
                plannedRoute.removeAll()
                plannedRouteWaypoints.removeAll()
                plannedRouteName = nil
            }
        }
        .onAppear {
            if !hasAppliedSuggestedType {
                if let suggestedWorkoutType {
                    type = suggestedWorkoutType
                }
                selectedAppleWorkout = AppleWorkoutSelection(
                    activityType: type.defaultAppleWorkoutActivityType,
                    locationType: nil
                )
                hasAppliedSuggestedType = true
            }
        }
        .onChange(of: selectedAppleWorkout) { _, newSelection in
            type = newSelection.activityType.mappedWorkoutType
        }
        .onChange(of: activeExerciseSelection) { _, newValue in
            // Defer cleanup so we don't mutate the backing array while the
            // sheet is still using an index-based binding, which can cause
            // index-out-of-range crashes during dismissal.
            if newValue == nil {
                DispatchQueue.main.async {
                    exerciseEntries.removeAll { $0.isEmpty }
                }
            }
        }
    }

    private var appleWorkoutTypeCard: some View {
        Section {
            Picker("Apple Workout Type", selection: $selectedAppleWorkout) {
                ForEach(appleWorkoutActivityOptions) { selection in
                    Text(selection.displayName).tag(selection)
                }
            }
        } header: {
            Text("Apple Workout Type")
        } footer: {
            Text("Choose the exact Apple workout activity to store for this workout.")
        }
    }

    private var quickLogCard: some View {
        Section("Quick Log") {
            Text("Save a common workout in one tap.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(quickLogPresets, id: \.title) { preset in
                    Button {
                        quickSavePreset(preset)
                    } label: {
                        Text(preset.title)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(preset.type.tintColor.opacity(colorScheme == .dark ? 0.28 : 0.18))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || !canAddWorkout)
                }
            }
        }
    }

    private var dateCard: some View {
        Section("Date & Time") {
            DatePicker("Date", selection: $date)
                .datePickerStyle(.compact)
        }
    }

    private var durationCard: some View {
        Section("Duration") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                ForEach(quickDurations, id: \.self) { mins in
                    Button {
                        durationMinutes = mins
                    } label: {
                        Text("\(Int(mins)) min")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(durationMinutes == mins ? type.tintColor.opacity(0.2) : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(durationMinutes == mins ? type.tintColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(
                "Minutes",
                value: durationBinding,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
        }
    }

    private var strengthLiveSessionCard: some View {
        Section("Live Session") {
            Text("Optional. Use a full-screen session with an elapsed timer while you're training.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                sessionStartsWithTimer = true
                showingWorkoutSession = true
            } label: {
                Label("Start Live Workout", systemImage: "play.circle.fill")
            }
            .disabled(isSaving)
        }
    }

    private var strengthTemplatesCard: some View {
        Section {
            if let activeTemplateName {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeTemplateName)
                        .font(.body.weight(.semibold))
                    if totalPlannedSets > 0 {
                        Text("\(totalCompletedSets) of \(totalPlannedSets) sets completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let latest = strengthTemplates.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last used")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(latest.name)
                        .font(.body.weight(.semibold))
                }
            } else {
                Text("Save a common routine once, then load it instantly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !quickTemplateCandidates.isEmpty {
                ForEach(quickTemplateCandidates) { template in
                    Button {
                        applyStrengthTemplate(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(templateSummary(template))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if activeTemplateID == template.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.tintColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showingTemplateLibrary = true
            } label: {
                Label("Choose Template (Optional)", systemImage: "square.stack.3d.up")
            }

            if activeTemplateID != nil || !exerciseEntries.isEmpty {
                Button {
                    activeTemplateID = nil
                    exerciseEntries = []
                } label: {
                    Label("Start Without Template", systemImage: "arrow.counterclockwise")
                }
            }

            Button {
                newTemplateName = suggestedTemplateName
                showingSaveTemplateAlert = true
            } label: {
                Label("Save Current as Template", systemImage: "square.and.arrow.down")
            }
            .disabled(!canSaveCurrentEntriesAsTemplate)
        } header: {
            HStack {
                Text("Strength Templates")
                Spacer()
                Text("\(strengthTemplates.count) saved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var distanceCard: some View {
        Section("Distance") {
            TextField(
                "Kilometers",
                value: distanceBinding,
                format: .number.precision(.fractionLength(0...3))
            )
            .keyboardType(.decimalPad)
        }
    }

    private var routePlannerCard: some View {
        Section {
            if plannedRoute.count > 1 {
                RouteMapView(route: plannedRoute)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingRoutePlanner = true
                    }

                HStack {
                    Label("\(String(format: "%.2f", plannedRoute.routeDistanceKilometers)) km", systemImage: "ruler")
                    Spacer()
                    Text(plannedRouteName ?? "\(plannedRoute.count) points")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))

                Button {
                    showingRoutePlanner = true
                } label: {
                    Label("Edit Route", systemImage: "map")
                }

                if !reusableRoutes.isEmpty {
                    Button {
                        showingSavedRoutePicker = true
                    } label: {
                        Label("Choose Saved Route", systemImage: "map.fill")
                    }
                }

                Button(role: .destructive) {
                    plannedRoute.removeAll()
                    plannedRouteWaypoints.removeAll()
                    plannedRouteName = nil
                } label: {
                    Label("Remove Route", systemImage: "trash")
                }
            } else {
                Text("Create a route by dropping points on a map. The route distance will fill in automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    showingRoutePlanner = true
                } label: {
                    Label("Plan Route on Map", systemImage: "map")
                }

                if !reusableRoutes.isEmpty {
                    Button {
                        showingSavedRoutePicker = true
                    } label: {
                        Label("Choose Saved Route", systemImage: "map.fill")
                    }
                }
            }
        } header: {
            Text("Route")
        }
    }

    private var ratingCard: some View {
        Section("Workout Rating") {
            if workoutRating == nil {
                Button {
                    workoutRating = 5.0
                } label: {
                    Label("Add Rating", systemImage: "star")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(type.tintColor.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(format: "%.1f / 10", workoutRating ?? 0))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button("Clear") {
                            workoutRating = nil
                        }
                        .font(.caption.weight(.semibold))
                    }

                    Slider(value: workoutRatingBinding, in: 0...10, step: 0.5)
                        .tint(type.tintColor)
                }
            }
        }
    }

    private var exercisesCard: some View {
        Section("Exercises") {
            HStack {
                Text("\(trackedExerciseCount) exercise\(trackedExerciseCount == 1 ? "" : "s") logged")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedExerciseDetailsCount) with full sets/reps/weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if exerciseEntries.isEmpty {
                Text("Add sets/reps/weight to track lifts like Bench Press and calculate personal bests.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(exerciseEntries) { entry in
                        let subcategoryName = allSubcategories.first(where: { $0.id == entry.subcategoryID })?.name
                        Button {
                            activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: ExerciseIconMapper.icon(for: entry.trimmedName))
                                    .font(.system(size: 18))
                                    .foregroundStyle(ExerciseIconMapper.iconColor(for: entry.trimmedName))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.trimmedName.isEmpty ? "Unnamed exercise" : entry.trimmedName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if let subcategoryName, !subcategoryName.isEmpty {
                                        Text(subcategoryName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    if let effortScore = entry.effortScore {
                                        Label("\(effortScore)/10 tough", systemImage: "gauge.medium")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    if !entry.setSummaryLines.isEmpty {
                                        Text(entry.setSummaryLines.joined(separator: "\n"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }

                                Spacer()

                                HStack(spacing: 10) {
                                    if let completionLabel = nextSetCompletionLabel(for: entry) {
                                        Button(completionLabel) {
                                            markNextSetDone(for: entry.id)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(.bordered)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                exerciseEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if entry.id != exerciseEntries.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }

            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Label("Add Exercises", systemImage: "plus.circle.fill")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !exerciseEntries.isEmpty {
                Button {
                    addAndEditNewExercise()
                } label: {
                    HStack {
                        Label("Add Custom Exercise", systemImage: "square.and.pencil")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesCard: some View {
        Section("Notes") {
            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var advancedSectionCard: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingAdvancedFields.toggle()
                }
            } label: {
                HStack {
                    Text("More details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showingAdvancedFields ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        let action = {
            guard !isSaving else { return }
            guard canAddWorkout else {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showingPaywall = true
                }
                return
            }
            if isStrengthSessionType {
                saveStrengthWorkout(
                    startDate: date,
                    duration: durationMinutes * 60,
                    entries: exerciseEntries
                )
                return
            }
            let workout = Workout(
                type: type,
                startDate: date,
                duration: durationMinutes * 60,
                distance: showsDistance && distanceKilometers > 0 ? distanceKilometers : nil,
                rating: workoutRating,
                notes: notes.isEmpty ? nil : notes,
                categories: nil,
                subcategories: nil,
                exercises: exerciseEntries.enumerated().compactMap { index, entry in
                    WorkoutExerciseFactory.make(from: entry, orderIndex: index, subcategories: allSubcategories)
                },
                hkActivityTypeRaw: Int(appleWorkoutActivityType.rawValue),
                hkLocationTypeRaw: appleWorkoutLocationType?.rawValue
            )
            attemptSaveWorkout(workout, persistTemplatesFrom: exerciseEntries)
        }

        let label = {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: canAddWorkout ? "checkmark.circle.fill" : "crown.fill")
                        .font(.system(size: 20))
                }
                Text(saveButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }

        if #available(iOS 26, *) {
            Button(action: action, label: label)
                .buttonStyle(.glassProminent)
                .disabled(isSaving)
        } else {
            Button(action: action, label: label)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(canAddWorkout ? type.tintColor : Color.accentColor)
                )
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .disabled(isSaving)
        }
    }

    private var saveButtonTitle: String {
        if isSaving { return "Saving..." }
        if !canAddWorkout { return "Upgrade to Add More" }
        return "Save Workout"
    }

    private var canSaveCurrentEntriesAsTemplate: Bool {
        type == .strength && exerciseEntries.contains { !$0.trimmedName.isEmpty }
    }

    private var suggestedTemplateName: String {
        let base = "Template \(Date.now.formatted(date: .abbreviated, time: .omitted))"
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

    private var hasUnsavedChanges: Bool {
        let baselineType = suggestedWorkoutType ?? .other
        return type != baselineType ||
            selectedAppleWorkout != AppleWorkoutSelection(
                activityType: type.defaultAppleWorkoutActivityType,
                locationType: nil
            ) ||
            abs(date.timeIntervalSinceNow) > 120 ||
            durationMinutes != 30.0 ||
            distanceKilometers > 0 ||
            !plannedRoute.isEmpty ||
            workoutRating != nil ||
            !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !exerciseEntries.isEmpty
    }

    private func handleCancelTapped() {
        if hasUnsavedChanges {
            showingDiscardChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func saveWorkout(_ workout: Workout) {
        attachPlannedRoute(to: workout)
        modelContext.insert(workout)
        do {
            try modelContext.save()
            handleReviewPromptAfterSuccessfulSave()
            refreshSmartReminder(with: workout.startDate)
            Task { @MainActor in
                do {
                    let importer = HealthKitRecentWorkoutImporter()
                    _ = try await importer.importNewRecentWorkouts(into: modelContext, limit: 30)
                } catch {
                    print("[HealthKitAutoImport] Post-save reconciliation failed: \(error.localizedDescription)")
                }
            }
            dismiss()
        } catch {
            isSaving = false
        }
    }

    private func quickSavePreset(_ preset: (title: String, type: WorkoutType, durationMinutes: Double, distanceKilometers: Double?)) {
        guard !isSaving else { return }
        guard canAddWorkout else {
            Task {
                await purchaseManager.loadProducts()
                await purchaseManager.updatePurchasedProducts()
                showingPaywall = true
            }
            return
        }

        if preset.type == .strength {
            type = .strength
            selectedAppleWorkout = AppleWorkoutSelection(
                activityType: preset.type.defaultAppleWorkoutActivityType,
                locationType: nil
            )
            durationMinutes = preset.durationMinutes
            date = Date()
            saveStrengthWorkout(
                startDate: date,
                duration: preset.durationMinutes * 60,
                entries: []
            )
            return
        }

        let workout = Workout(
            type: preset.type,
            startDate: Date(),
            duration: preset.durationMinutes * 60,
            distance: preset.distanceKilometers,
            hkActivityTypeRaw: Int(preset.type.defaultAppleWorkoutActivityType.rawValue),
            hkLocationTypeRaw: nil
        )
        attemptSaveWorkout(workout)
    }

    private func handleReviewPromptAfterSuccessfulSave() {
        guard !hasShownWorkoutReviewPrompt else { return }
        reviewPromptLoggedWorkoutCount += 1
        guard reviewPromptLoggedWorkoutCount >= reviewPromptWorkoutThreshold else { return }

        requestReview()
        hasShownWorkoutReviewPrompt = true
    }

    private func refreshSmartReminder(with newWorkoutDate: Date) {
        let dates = (workouts.map(\.startDate) + [newWorkoutDate]).sorted()
        NotificationManager.shared.refreshSmartConsistencyReminder(workoutDates: dates)
    }

    private func saveStrengthWorkout(startDate: Date, duration: TimeInterval, entries: [ExerciseLogEntry]) {
        guard !isSaving else { return }
        let resolvedEntries = WorkoutClassificationBuilder.entriesWithInferredSubcategories(
            entries,
            exerciseTemplates: exerciseTemplates,
            quickAddOptions: quickAddOptions
        )
        let classification = WorkoutClassificationBuilder.build(
            from: resolvedEntries,
            subcategories: allSubcategories
        )
        let workout = Workout(
            type: .strength,
            startDate: startDate,
            duration: duration,
            distance: nil,
            rating: workoutRating,
            notes: notes.isEmpty ? nil : notes,
            categories: classification.categories.isEmpty ? nil : classification.categories,
            subcategories: classification.subcategories.isEmpty ? nil : classification.subcategories,
            exercises: resolvedEntries.enumerated().compactMap { index, entry in
                WorkoutExerciseFactory.make(from: entry, orderIndex: index, subcategories: allSubcategories)
            },
            hkActivityTypeRaw: Int(appleWorkoutActivityType.rawValue),
            hkLocationTypeRaw: appleWorkoutLocationType?.rawValue
        )
        attemptSaveWorkout(workout, persistTemplatesFrom: resolvedEntries)
    }

    private func attemptSaveWorkout(_ workout: Workout, persistTemplatesFrom entries: [ExerciseLogEntry]? = nil) {
        guard !isSaving else { return }
        isSaving = true

        if hasExistingWorkoutOfSameTypeOnSameDay(as: workout) {
            pendingWorkoutToSave = workout
            pendingTemplateEntries = entries
            showingDuplicateTypeAlert = true
            return
        }

        performSave(workout, persistTemplatesFrom: entries)
    }

    private func performSave(_ workout: Workout, persistTemplatesFrom entries: [ExerciseLogEntry]? = nil) {
        if let entries {
            persistExerciseTemplates(from: entries)
        }
        saveWorkout(workout)
    }

    private func attachPlannedRoute(to workout: Workout) {
        guard canPlanRoute, plannedRoute.count > 1, workout.route == nil else { return }

        let route = WorkoutRoute()
        route.name = plannedRouteName
        route.decodedRoute = plannedRoute
        route.decodedWaypoints = plannedRouteWaypoints.isEmpty ? plannedRoute : plannedRouteWaypoints
        route.workout = workout
        workout.route = route
        modelContext.insert(route)
    }

    private func hasExistingWorkoutOfSameTypeOnSameDay(as workout: Workout) -> Bool {
        let calendar = Calendar.current
        return workouts.contains { existing in
            existing.type == workout.type &&
            calendar.isDate(existing.startDate, inSameDayAs: workout.startDate)
        }
    }

    private func addAndEditNewExercise() {
        let newEntry = defaultExerciseEntry()
        exerciseEntries.append(newEntry)
        activeExerciseSelection = ExerciseEditorSelection(id: newEntry.id)
    }

    private func addExercise(from option: ExerciseQuickAddOption) {
        var entry = ExerciseLogEntry(name: option.name, subcategoryID: option.subcategoryID)
        if let recentMatch = exerciseEntries.last(where: { $0.subcategoryID == option.subcategoryID }) {
            entry.sets = recentMatch.sets
            entry.reps = recentMatch.reps
        }
        exerciseEntries.append(entry)
    }

    private func saveExerciseTemplateIfNeeded(name: String, subcategoryID: UUID) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let subcategory = allSubcategories.first(where: { $0.id == subcategoryID }) else {
            return
        }

        let exists = exerciseTemplates.contains {
            $0.subcategory?.id == subcategoryID &&
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedName) == .orderedSame
        }
        guard !exists else { return }

        let order = exerciseTemplates.filter { $0.subcategory?.id == subcategoryID }.count
        modelContext.insert(SubcategoryExercise(name: trimmedName, subcategory: subcategory, orderIndex: order))
        try? modelContext.save()
    }

    private func exerciseSummary(for entry: ExerciseLogEntry) -> String? {
        let setsText = entry.effectiveSetCount.map { "\($0)x" }
        let repsText = entry.effectiveReps.map { "\($0)" }
        let weightText: String? = {
            guard let w = entry.effectiveWeight, w > 0 else { return nil }
            return "\(ExerciseLogEntry.displayWeight(w)) kg"
        }()

        let primary = [setsText, repsText].compactMap { $0 }.joined(separator: " ")
        let withWeight: String
        if let weightText {
            withWeight = primary.isEmpty ? weightText : "\(primary) · \(weightText)"
        } else {
            withWeight = primary
        }

        let progressSuffix: String = {
            guard !entry.setEntries.isEmpty else { return "" }
            return " · \(entry.completedSetCount)/\(entry.setEntries.count) done"
        }()

        let summary = withWeight + progressSuffix
        return summary.isEmpty ? nil : summary
    }

    private func nextSetCompletionLabel(for entry: ExerciseLogEntry) -> String? {
        guard !entry.setEntries.isEmpty else { return nil }
        if let nextIndex = entry.setEntries.firstIndex(where: { !$0.isCompleted }) {
            return "Set \(nextIndex + 1) done"
        }
        return "Reset"
    }

    private func markNextSetDone(for entryID: UUID) {
        guard let entryIndex = exerciseEntries.firstIndex(where: { $0.id == entryID }) else { return }
        if let nextIndex = exerciseEntries[entryIndex].setEntries.firstIndex(where: { !$0.isCompleted }) {
            exerciseEntries[entryIndex].setEntries[nextIndex].isCompleted = true
            HapticManager.lightImpact()
            return
        }

        for index in exerciseEntries[entryIndex].setEntries.indices {
            exerciseEntries[entryIndex].setEntries[index].isCompleted = false
        }
        HapticManager.lightImpact()
    }

    private func exerciseNotes(for entry: ExerciseLogEntry) -> String? {
        let lines = entry.setSummaryLines
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private func persistExerciseTemplates(from entries: [ExerciseLogEntry]) {
        var insertedKeys: Set<String> = []
        for entry in entries {
            let name = entry.trimmedName
            guard !name.isEmpty, let subcategoryID = entry.subcategoryID else { continue }

            let key = "\(subcategoryID.uuidString)|\(name.lowercased())"
            guard !insertedKeys.contains(key) else { continue }

            let exists = exerciseTemplates.contains {
                $0.subcategory?.id == subcategoryID &&
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }
            guard !exists,
                  let subcategory = allSubcategories.first(where: { $0.id == subcategoryID }) else { continue }

            let order = exerciseTemplates.filter { $0.subcategory?.id == subcategoryID }.count
            let template = SubcategoryExercise(name: name, subcategory: subcategory, orderIndex: order)
            modelContext.insert(template)
            insertedKeys.insert(key)
        }
        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }

    private func defaultExerciseEntry() -> ExerciseLogEntry {
        guard let firstSubcategory = availableExerciseSubcategories.first else { return ExerciseLogEntry() }
        let templates = quickAddOptions.filter { $0.subcategoryID == firstSubcategory.id }.map(\.name)
        return ExerciseLogEntry(
            name: templates.first ?? "",
            subcategoryID: firstSubcategory.id
        )
    }

    private var templateLibrarySheet: some View {
        NavigationStack {
            List {
                if strengthTemplates.isEmpty {
                    Text("No templates yet. Save your current strength exercises to create one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(strengthTemplates) { template in
                        Button {
                            applyStrengthTemplate(template)
                            showingTemplateLibrary = false
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(templateSummary(template))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.down.doc")
                                    .foregroundStyle(type.tintColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteStrengthTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Strength Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showingTemplateLibrary = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        StrengthTemplatesManagementView()
                    } label: {
                        Text("Manage")
                    }
                }
            }
        }
    }

    private func templateSummary(_ template: StrengthWorkoutTemplate) -> String {
        let count = template.exercises?.count ?? 0
        let updated = template.updatedAt.formatted(date: .abbreviated, time: .omitted)
        let categoryName = template.activityDisplayName
        return "\(categoryName) • \(count) exercise\(count == 1 ? "" : "s") • Updated \(updated)"
    }

    private func applyStrengthTemplate(_ template: StrengthWorkoutTemplate) {
        activeTemplateID = template.id
        let templateActivity = template.appleWorkoutActivityType
        selectedAppleWorkout = AppleWorkoutSelection.normalized(
            activityType: templateActivity,
            locationType: nil
        )
        type = templateActivity.mappedWorkoutType
        let sortedExercises = (template.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        exerciseEntries = sortedExercises.map { item in
            let decodedPlan = item.decodedSetPlan()
            let plannedSetEntries: [ExerciseSetEntry]
            if !decodedPlan.isEmpty {
                plannedSetEntries = decodedPlan.map {
                    ExerciseSetEntry(reps: max($0.reps, 0), weight: max($0.weight, 0), isCompleted: false)
                }
            } else {
                let plannedSetCount = max(item.sets ?? 0, 0)
                let plannedReps = max(item.reps ?? 0, 0)
                let plannedWeight = max(item.weight ?? 0, 0)
                plannedSetEntries = (0..<plannedSetCount).map { _ in
                    ExerciseSetEntry(reps: plannedReps, weight: plannedWeight, isCompleted: false)
                }
            }
            return ExerciseLogEntry(
                name: item.name,
                sets: item.sets,
                reps: item.reps,
                weight: item.weight,
                subcategoryID: item.subcategoryID,
                setEntries: plannedSetEntries
            )
        }
        exerciseEntries = WorkoutClassificationBuilder.entriesWithInferredSubcategories(
            exerciseEntries,
            exerciseTemplates: exerciseTemplates,
            quickAddOptions: quickAddOptions
        )
        if exerciseEntries.isEmpty {
            exerciseEntries = [defaultExerciseEntry()]
        }
    }

    private func saveStrengthTemplate(named rawName: String, from entries: [ExerciseLogEntry]) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let snapshot = entries
            .enumerated()
            .compactMap { index, entry -> StrengthWorkoutTemplateExercise? in
                let exerciseName = entry.trimmedName
                guard !exerciseName.isEmpty else { return nil }
                return StrengthWorkoutTemplateExercise(
                    name: exerciseName,
                    orderIndex: index,
                    sets: entry.effectiveSetCount,
                    reps: entry.effectiveReps,
                    weight: entry.effectiveWeight,
                    subcategoryID: entry.subcategoryID,
                    setPlanJSON: StrengthWorkoutTemplateExercise.encodeSetPlan(
                        entry.setEntries.map { setEntry in
                            TemplateSetPlanEntry(reps: max(setEntry.reps, 0), weight: max(setEntry.weight, 0))
                        }
                    )
                )
            }
        guard !snapshot.isEmpty else { return }

        if let existing = strengthTemplates.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            existing.name = name
            existing.mainCategoryRawValue = type.rawValue
            existing.appleWorkoutActivityType = appleWorkoutActivityType
            existing.updatedAt = Date()
            existing.exercises = snapshot
        } else {
            let template = StrengthWorkoutTemplate(
                name: name,
                mainCategoryRawValue: type.rawValue,
                appleWorkoutActivityType: appleWorkoutActivityType,
                createdAt: Date(),
                updatedAt: Date(),
                exercises: snapshot
            )
            modelContext.insert(template)
        }
        try? modelContext.save()
    }

    private func deleteStrengthTemplate(_ template: StrengthWorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }
}

// MARK: - Type Option Button
#Preview {
    AddWorkoutView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, SubcategoryExercise.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}
