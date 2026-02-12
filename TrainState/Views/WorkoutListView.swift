import SwiftUI
import SwiftData
import RevenueCatUI
import HealthKit

struct WorkoutListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var showingPaywall = false
    @State private var selectedFilter: WorkoutFilter = .all
    @AppStorage("healthKitRecentWorkoutsCache") private var healthKitRecentWorkoutsCacheData: Data = Data()
    @State private var recentHealthKitWorkouts: [HealthKitRecentWorkoutMenuItem] = []
    @State private var isLoadingRecentHealthKitWorkouts = false
    @State private var isImportingHealthKitWorkout = false
    @State private var healthKitImportErrorMessage: String?
    @State private var healthKitImportSuccessMessage: String?
    @State private var newlyImportedHealthKitUUIDs: Set<String> = []
    @State private var pendingHealthKitItem: HealthKitRecentWorkoutMenuItem?
    @State private var pendingAttachItem: HealthKitRecentWorkoutMenuItem?
    @State private var showingHealthKitActionSheet = false
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
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                        Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        Color(.systemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if groupedVisibleWorkouts.isEmpty {
                    ScrollView {
                        GlassEffectContainerWrapper(spacing: 24) {
                            VStack(spacing: 24) {
                                ContentUnavailableView {
                                    Label("No Workouts", systemImage: "figure.run")
                                } description: {
                                    Text("Tap + to log your first workout.")
                                }
                                .padding(.top, 40)

                                if showLimitsCard {
                                    limitsCard
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                } else {
                    ScrollView {
                        GlassEffectContainerWrapper(spacing: 16) {
                            LazyVStack(spacing: 16) {
                                if showLimitsCard {
                                    limitsCard
                                }
                                ForEach(groupedVisibleWorkouts, id: \.date) { entry in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(sectionHeaderTitle(for: entry.date))
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)

                                        VStack(spacing: 12) {
                                            ForEach(entry.items, id: \.id) { workout in
                                                NavigationLink {
                                                    WorkoutDetailView(workout: workout)
                                                } label: {
                                                    WorkoutRowView(workout: workout)
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                if selectedFilter == filter {
                                    Label(filter.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(filter.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    Menu {
                        Section("HealthKit") {
                            Button {
                                Task { await loadRecentHealthKitWorkouts() }
                            } label: {
                                Label("Refresh Recent Workouts", systemImage: "arrow.clockwise")
                            }
                            .menuActionDismissBehavior(.disabled)
                        }

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
                                    let isImported = importedHealthKitUUIDs.contains(candidate.hkUUID) || newlyImportedHealthKitUUIDs.contains(candidate.hkUUID)
                                    Button {
                                        pendingHealthKitItem = candidate
                                        showingHealthKitActionSheet = true
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(healthKitWorkoutTitle(candidate))
                                                Text(healthKitWorkoutSubtitle(candidate))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
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
                            }
                        }
                    } label: {
                        Image(systemName: "heart.text.square")
                    }
                    .disabled(isImportingHealthKitWorkout)
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
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .sheet(isPresented: $showingPaywall) {
                if let offering = purchaseManager.offerings?.current {
                    PaywallView(offering: offering)
                } else {
                    PaywallPlaceholderView(onDismiss: { showingPaywall = false })
                }
            }
            .alert("HealthKit Import", isPresented: Binding(
                get: { healthKitImportErrorMessage != nil || healthKitImportSuccessMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        healthKitImportErrorMessage = nil
                        healthKitImportSuccessMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    healthKitImportErrorMessage = nil
                    healthKitImportSuccessMessage = nil
                }
            } message: {
                if let healthKitImportErrorMessage {
                    Text(healthKitImportErrorMessage)
                } else if let healthKitImportSuccessMessage {
                    Text(healthKitImportSuccessMessage)
                }
            }
            .confirmationDialog(
                "Use this Apple Health workout",
                isPresented: $showingHealthKitActionSheet,
                presenting: pendingHealthKitItem
            ) { item in
                Button("Attach to an existing workout") {
                    pendingAttachItem = item
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
        }
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Free Tier Limits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

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
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Premium")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
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
        guard let filterType = selectedFilter.workoutType else { return workouts }
        return workouts.filter { $0.type == filterType }
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

    @MainActor
    private func loadRecentHealthKitWorkouts() async {
        guard !isLoadingRecentHealthKitWorkouts else { return }
        isLoadingRecentHealthKitWorkouts = true
        defer { isLoadingRecentHealthKitWorkouts = false }

        do {
            recentHealthKitWorkouts = try await healthKitImporter.fetchRecentWorkouts(limit: 10)
            saveRecentHealthKitWorkoutsCache(recentHealthKitWorkouts)
            if recentHealthKitWorkouts.isEmpty {
                healthKitImportSuccessMessage = "No recent workouts were found."
                healthKitImportErrorMessage = nil
            }
        } catch {
            healthKitImportErrorMessage = error.localizedDescription
            healthKitImportSuccessMessage = nil
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
            healthKitImportSuccessMessage = "Imported \(healthKitWorkoutTitle(candidate))."
            healthKitImportErrorMessage = nil
        } catch {
            healthKitImportErrorMessage = "Import failed: \(error.localizedDescription)"
            healthKitImportSuccessMessage = nil
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
            let workoutTitle = "\(workout.type.rawValue) • \(workout.startDate.formatted(date: .abbreviated, time: .shortened))"
            healthKitImportSuccessMessage = "Linked \(healthKitWorkoutTitle(candidate)) to \(workoutTitle)."
            healthKitImportErrorMessage = nil
        } catch {
            healthKitImportErrorMessage = "Attach failed: \(error.localizedDescription)"
            healthKitImportSuccessMessage = nil
        }
    }

    private func attachableWorkouts(for item: HealthKitRecentWorkoutMenuItem) -> [Workout] {
        let calendar = Calendar.current
        // Prefer workouts logged on the same day as the HealthKit workout.
        let sameDay = workouts.filter { calendar.isDate($0.startDate, inSameDayAs: item.startDate) }
        if !sameDay.isEmpty {
            return sameDay
        }
        // Fallback: recent workouts within the last 2 days.
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: item.startDate) ?? item.startDate
        return workouts.filter { $0.startDate >= twoDaysAgo && $0.startDate <= Date() }
    }

    private func healthKitWorkoutTitle(_ candidate: HealthKitRecentWorkoutMenuItem) -> String {
        let type = mappedWorkoutType(from: candidate.activityType)
        return "\(type.rawValue) • \(formattedDuration(candidate.duration)) • \(relativeDateCompactLabel(for: candidate.startDate))"
    }

    private func healthKitWorkoutSubtitle(_ candidate: HealthKitRecentWorkoutMenuItem) -> String {
        var parts: [String] = [
            relativeWorkoutDateLabel(for: candidate.startDate)
        ]
        if let distance = candidate.distanceKilometers, distance > 0 {
            parts.append(String(format: "%.1f km", distance))
        }
        parts.append(candidate.sourceName)
        return parts.joined(separator: " · ")
    }

    private func relativeWorkoutDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let timeText = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return "Today at \(timeText)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeText)"
        }
        return "\(date.formatted(date: .abbreviated, time: .omitted)) at \(timeText)"
    }

    private func relativeDateCompactLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func mappedWorkoutType(from activity: HKWorkoutActivityType) -> WorkoutType {
        switch activity {
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .yoga:
            return .yoga
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .strength
        case .walking, .hiking, .elliptical, .rowing, .stairClimbing, .mixedCardio:
            return .cardio
        default:
            return .other
        }
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
