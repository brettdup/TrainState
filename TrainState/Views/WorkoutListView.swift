import SwiftUI
import SwiftData
import HealthKit

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var selectedFilter = "All"
    @State private var selectedWorkoutForDetail: Workout?
    @State private var showingWellDoneSheet = false
    @State private var isRefreshing = false
    @State private var showingPremiumPaywall = false
    @State private var lastRefreshTime: Date?
    
    // Cached expensive computations
    @State private var cachedWorkoutsThisMonth: [Workout] = []
    @State private var cachedRunningCount: Int = 0
    @State private var cachedStrengthCount: Int = 0
    @State private var lastWorkoutsHash: Int = 0
    
    private let healthStore = HKHealthStore()
    
    // Toast feedback state
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isLoading = false
    
    // MARK: - Stats
    var workoutsThisMonth: [Workout] {
        cachedWorkoutsThisMonth
    }
    
    var runningThisMonthCount: Int {
        cachedRunningCount
    }
    
    var strengthThisMonthCount: Int {
        cachedStrengthCount
    }
    
    var filteredWorkouts: [Workout] {
        switch selectedFilter {
        case "Strength":
            return workouts.filter { $0.type == .strength }
        case "Running":
            return workouts.filter { $0.type == .running }
        case "Cardio":
            return workouts.filter { $0.type == .cardio }
        default:
            return Array(workouts)
        }
    }
    
    var displayedWorkouts: [Workout] {
        if !purchaseManager.hasActiveSubscription {
            return Array(filteredWorkouts.prefix(5))
        }
        return filteredWorkouts
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Stats Section
                Section {
                    statsCardsView
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                // Workouts Section
                Section {
                    ForEach(displayedWorkouts) { workout in
                        WorkoutRowView(
                            workout: workout,
                            onTap: { selectedWorkoutForDetail = workout },
                            menuItems: [
                                ContextMenuItem(view: AnyView(Button {
                                    selectedWorkoutForDetail = workout // Edit
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                })),
                                ContextMenuItem(view: AnyView(Button(role: .destructive) {
                                    deleteWorkout(workout)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }))
                            ]
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                        .listRowSeparator(.hidden)
                    }
                    
                    // Premium Upgrade Row
                    if !purchaseManager.hasActiveSubscription && workouts.count > 5 {
                        premiumUpgradeRow
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack {
                        Text("\(filteredWorkouts.count) Workouts")
                        Spacer()
                        filterMenu
                    }
                } footer: {
                    if purchaseManager.hasActiveSubscription && filteredWorkouts.count > displayedWorkouts.count {
                        Text("\(filteredWorkouts.count - displayedWorkouts.count) more workouts available")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            Task { await refreshData() }
                        }) {
                            Label("Refresh Workouts", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                        
                        Button(action: {
                            removeDuplicateWorkouts()
                        }) {
                            Label("Remove Duplicates", systemImage: "trash")
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else if showToast {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if isRefreshing {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        // Test button for Well Done sheet (remove in production)
                        Button(action: {
                            showingWellDoneSheet = true
                        }) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                        
                        Button(action: {
                            showingAddWorkout = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await refreshData()
            }
            .sheet(item: $selectedWorkoutForDetail) { workout in
                NavigationStack {
                    WorkoutDetailView(workout: workout)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(.regularMaterial)
            }
            .sheet(isPresented: $showingWellDoneSheet) {
                WellDoneSheetView(isPresented: $showingWellDoneSheet)
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingPremiumPaywall) {
                WorkoutPremiumPaywallView(
                    isPresented: $showingPremiumPaywall,
                    onPurchase: {
                        Task {
                            if let product = purchaseManager.products.first(where: { $0.id == "Premium1Month" }) {
                                do {
                                    try await purchaseManager.purchase(product)
                                    showingPremiumPaywall = false
                                } catch {
                                    print("Purchase failed:", error)
                                }
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .onAppear {
                updateCachedData()
            }
            .onChange(of: workouts) { _, _ in
                updateCachedData()
            }
        }
    }
    
    // MARK: - View Components
    
    private var statsCardsView: some View {
        VStack(spacing: 8) {
            // Top row - This Month and Total
            HStack(spacing: 12) {
                StatCardView(
                    title: "This Month",
                    value: "\(workoutsThisMonth.count)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCardView(
                    title: "Total",
                    value: "\(workouts.count)",
                    icon: "chart.bar.fill",
                    color: .green
                )
            }
            
            // Bottom row - Strength and Running
            HStack(spacing: 12) {
                StatCardView(
                    title: "Strength",
                    value: "\(strengthThisMonthCount)",
                    icon: "dumbbell.fill",
                    color: .orange
                )
                
                StatCardView(
                    title: "Running",
                    value: "\(runningThisMonthCount)",
                    icon: "figure.run",
                    color: .mint
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var filterMenu: some View {
        Menu {
            ForEach(["All", "Strength", "Running", "Cardio"], id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                }) {
                    Label(filter, systemImage: iconName(for: filter))
                    if selectedFilter == filter {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.iconOnly)
        }
    }
    
    private var premiumUpgradeRow: some View {
        Button(action: {
            showingPremiumPaywall = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock All Workouts")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("View unlimited workout history and premium features")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Functions
    
    private func removeDuplicateWorkouts() {
        let allWorkouts = workouts
        var workoutsToKeep: [Workout] = []
        var duplicatesToDelete: [Workout] = []
        
        // Strategy 1: Remove exact ID duplicates
        var seenIDs = Set<UUID>()
        for workout in allWorkouts {
            if seenIDs.contains(workout.id) {
                duplicatesToDelete.append(workout)
            } else {
                seenIDs.insert(workout.id)
                workoutsToKeep.append(workout)
            }
        }
        
        // Strategy 2: Remove fuzzy duplicates
        var finalWorkouts: [Workout] = []
        var processedWorkouts = Set<String>()
        
        for workout in workoutsToKeep {
            let signature = "\(workout.type.rawValue)_\(Int(workout.startDate.timeIntervalSince1970))_\(Int(workout.duration))"
            
            if processedWorkouts.contains(signature) {
                let timeTolerance: TimeInterval = 5
                let durationTolerance: TimeInterval = 5
                
                let isDuplicate = finalWorkouts.contains { existing in
                    let timeMatch = abs(existing.startDate.timeIntervalSince1970 - workout.startDate.timeIntervalSince1970) < timeTolerance
                    let durationMatch = abs(existing.duration - workout.duration) < durationTolerance
                    let typeMatch = existing.type == workout.type
                    
                    var caloriesMatch = true
                    if let existingCalories = existing.calories, let workoutCalories = workout.calories {
                        caloriesMatch = abs(existingCalories - workoutCalories) < 50
                    }
                    
                    var distanceMatch = true
                    if let existingDistance = existing.distance, let workoutDistance = workout.distance {
                        distanceMatch = abs(existingDistance - workoutDistance) < 100
                    }
                    
                    return timeMatch && durationMatch && typeMatch && caloriesMatch && distanceMatch
                }
                
                if isDuplicate {
                    duplicatesToDelete.append(workout)
                } else {
                    finalWorkouts.append(workout)
                    processedWorkouts.insert(signature)
                }
            } else {
                finalWorkouts.append(workout)
                processedWorkouts.insert(signature)
            }
        }
        
        if !duplicatesToDelete.isEmpty {
            for duplicate in duplicatesToDelete {
                modelContext.delete(duplicate)
            }
            
            do {
                try modelContext.save()
                DispatchQueue.main.async {
                    self.toastMessage = "Removed \(duplicatesToDelete.count) duplicate workouts"
                    self.showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showToast = false
                    }
                }
            } catch {
                print("Error removing duplicates: \(error)")
            }
        } else {
            DispatchQueue.main.async {
                self.toastMessage = "No duplicates found"
                self.showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showToast = false
                }
            }
        }
    }
    
    private func refreshData() async {
        // Prevent concurrent refreshes
        guard !isRefreshing else {
            print("[UI] Refresh already in progress, skipping")
            return
        }
        
        // Rate limiting - prevent refreshes more frequent than 30 seconds
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < 30 {
            print("[UI] Refresh rate limited - last refresh was \(Int(Date().timeIntervalSince(lastRefresh))) seconds ago")
            await MainActor.run {
                toastMessage = "Please wait before refreshing again"
                showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                }
            }
            return
        }
        
        await MainActor.run {
            isRefreshing = true
            isLoading = true
            showToast = true
            lastRefreshTime = Date()
        }
        
        defer {
            Task { @MainActor in
                isRefreshing = false
                isLoading = false
            }
        }
        
        let isPremium = purchaseManager.hasActiveSubscription
        if isPremium {
            await CloudKitManager.shared.waitForSyncCompletion()
            
            do {
                let cloudStatus = try await CloudKitManager.shared.checkCloudStatus()
                if !cloudStatus {
                    print("[UI] CloudKit unavailable for premium user - proceeding with HealthKit only")
                }
            } catch {
                print("[UI] CloudKit status check failed: \(error.localizedDescription)")
            }
        }
        
        do {
            let workoutCountBefore = workouts.count
            
            // Only import if we haven't imported recently (within last 5 minutes)
            let lastImportKey = "LastHealthKitImportDate"
            let lastImportDate = UserDefaults.standard.object(forKey: lastImportKey) as? Date
            let timeSinceLastImport = lastImportDate?.timeIntervalSinceNow ?? -3600 // Default to 1 hour ago
            
            if timeSinceLastImport > -300 { // 5 minutes
                print("[UI] Skipping import - last import was \(Int(-timeSinceLastImport)) seconds ago")
                await MainActor.run {
                    toastMessage = "Already up to date"
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showToast = false
                    }
                }
                return
            }
            
            // Check if there are actually new workouts to import
            let hasNewWorkouts = await checkForNewWorkouts()
            if !hasNewWorkouts {
                print("[UI] No new workouts found in HealthKit")
                await MainActor.run {
                    toastMessage = "No new workouts found"
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showToast = false
                    }
                }
                return
            }
            
            // Perform the import
            try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
            
            // Update last import date
            UserDefaults.standard.set(Date(), forKey: lastImportKey)
            
            let workoutCountAfter = workouts.count
            
            await MainActor.run {
                toastMessage = "Workouts refreshed!"
                showToast = true
                
                if workoutCountAfter > workoutCountBefore {
                    showingWellDoneSheet = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                }
            }
        } catch {
            await MainActor.run {
                toastMessage = "Error refreshing workouts"
                showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                }
            }
        }
    }
    
    private func checkForNewWorkouts() async -> Bool {
        do {
            // Get existing workout UUIDs
            let existingWorkouts = try modelContext.fetch(FetchDescriptor<Workout>())
            let existingUUIDs = Set(existingWorkouts.compactMap { $0.healthKitUUID })
            
            // Fetch workouts from HealthKit
            let healthKitWorkouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                let workoutPredicate = HKQuery.predicateForWorkouts(with: .greaterThan, duration: 0)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                
                let query = HKSampleQuery(
                    sampleType: .workoutType(),
                    predicate: workoutPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples as? [HKWorkout] ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            // Check if any HealthKit workouts are not in our database
            let newWorkouts = healthKitWorkouts.filter { !existingUUIDs.contains($0.uuid) }
            print("[UI] Found \(newWorkouts.count) new workouts out of \(healthKitWorkouts.count) total HealthKit workouts")
            
            return !newWorkouts.isEmpty
        } catch {
            print("[UI] Error checking for new workouts: \(error)")
            return false
        }
    }
    
    private func updateCachedData() {
        let newHash = workouts.map { $0.id }.hashValue
        if newHash != lastWorkoutsHash || cachedWorkoutsThisMonth.isEmpty {
            lastWorkoutsHash = newHash
            
            let calendar = Calendar.current
            let now = Date()
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                return
            }
            let endOfMonth: Date = {
                var comps = DateComponents()
                comps.month = 1
                comps.day = -1
                return calendar.date(byAdding: comps, to: startOfMonth) ?? now
            }()
            
            cachedWorkoutsThisMonth = workouts.filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
            cachedRunningCount = cachedWorkoutsThisMonth.filter { $0.type == .running }.count
            cachedStrengthCount = cachedWorkoutsThisMonth.filter { $0.type == .strength }.count
        }
    }
    
    private func iconName(for filter: String) -> String {
        switch filter {
        case "All": return "square.grid.2x2"
        case "Strength": return "dumbbell.fill"
        case "Running": return "figure.run"
        case "Cardio": return "heart.fill"
        default: return "square.grid.2x2"
        }
    }
    
    private func deleteWorkout(_ workout: Workout) {
        // TODO: Implement actual delete logic
        print("Delete workout: \(workout.id)")
    }
}

// MARK: - StatCardView
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1.5)
                )
        )
        .shadow(color: color.opacity(0.2), radius: 12, x: 0, y: 6)
        .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - WorkoutRowView
struct WorkoutRowView: View {
    let workout: Workout
    var onTap: (() -> Void)? = nil
    var contextMenu: (() -> Void)? = nil // Not used directly, just for API compatibility
    var menuItems: [ContextMenuItem] = []
    
    private var iconName: String {
        switch workout.type {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    private var iconColor: Color {
        switch workout.type {
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .yoga: return .purple
        case .strength: return .orange
        case .cardio: return .red
        case .other: return .gray
        }
    }
    
    var body: some View {
        Button(action: { 
            onTap?()
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            HStack(spacing: 16) {
                // Simple icon with subtle background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }
                .frame(width: 40, height: 40)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(formattedDate(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let firstCategory = workout.categories?.first {
                        Text(firstCategory.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(categoryColor(for: firstCategory))
                            )
                    }
                }
                
                Spacer()
                
                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDuration(workout.duration))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    if workout.type == .running, let distance = workout.distance {
                        Text(String(format: "%.1f km", distance / 1000))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let calories = workout.calories {
                        Text("\(Int(calories)) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .shadow(color: .primary.opacity(0.08), radius: 8, x: 0, y: 4)
            .shadow(color: .primary.opacity(0.04), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            ForEach(menuItems) { item in
                item.view
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "E, MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
    
    private func categoryColor(for category: WorkoutCategory) -> Color {
        // Try to use the category's stored color first
        if let color = Color(hex: category.color) {
            return color
        }
        
        // Fallback to workout type color if category color is invalid
        return iconColor
    }
}

// Helper struct for context menu items
struct ContextMenuItem: Identifiable {
    let id = UUID()
    let view: AnyView
}

// Helper for conditional modifier
extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - WellDoneSheet View
struct WellDoneSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]

    var body: some View {
        VStack(spacing: 0) {
            // Success icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.15), .green.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.green)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Title and subtitle
            VStack(spacing: 6) {
                Text("Well Done!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                if let latestWorkout = workouts.first {
                    Text("Your \(latestWorkout.type.rawValue) workout has been imported")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
            
                        // Workout stats card
            if let latestWorkout = workouts.first {
                HStack(spacing: 0) {
                    // Duration
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "clock.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDuration(latestWorkout.duration))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            Text("Duration")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.blue.opacity(0.1), lineWidth: 1)
                            )
                    )
                    
                    // Divider
                    if let calories = latestWorkout.calories {
                        Rectangle()
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 1, height: 40)
                            .padding(.horizontal, 8)
                    }
                    
                    // Calories (if available)
                    if let calories = latestWorkout.calories {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange.opacity(0.2), .orange.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(calories))")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)
                                
                                Text("Calories")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.orange.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.orange.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .primary.opacity(0.05), radius: 8, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // Reminder text and button
            VStack(spacing: 16) {
                Text("Don't forget to categorize it to keep your log organized!")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // Action button
                Button("Got it!") {
                    isPresented = false
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.blue)
                )
                .padding(.horizontal, 20)
            }
            
            Spacer(minLength: 16)
        }
        .background(Color(.systemBackground))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Workout Premium Paywall View
struct WorkoutPremiumPaywallView: View {
    @Binding var isPresented: Bool
    let onPurchase: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                        
                        Text("Unlock Premium")
                            .font(.largeTitle.bold())
                        
                        Text("Access all your workouts and premium features")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                Section("Premium Features") {
                    Label("Unlimited workout history", systemImage: "infinity")
                    Label("Advanced analytics", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Custom categories", systemImage: "folder.fill")
                    Label("Cloud sync", systemImage: "icloud.fill")
                }
                
                Section {
                    Button(action: onPurchase) {
                        Text("Get Premium - $1.99/month")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    let preview = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
            configurations: config
        )
        
        let context = container.mainContext
        
        // Create categories
        let strengthCategory = WorkoutCategory(name: "Upper Body", color: "#FF6B35", workoutType: .strength)
        let runningCategory = WorkoutCategory(name: "Morning Run", color: "#4ECDC4", workoutType: .running)
        let cardioCategory = WorkoutCategory(name: "HIIT", color: "#FF6B9D", workoutType: .cardio)
        let yogaCategory = WorkoutCategory(name: "Vinyasa", color: "#9B59B6", workoutType: .yoga)
        let cyclingCategory = WorkoutCategory(name: "Road Cycling", color: "#2ECC71", workoutType: .cycling)
        let swimmingCategory = WorkoutCategory(name: "Freestyle", color: "#3498DB", workoutType: .swimming)
        
        context.insert(strengthCategory)
        context.insert(runningCategory)
        context.insert(cardioCategory)
        context.insert(yogaCategory)
        context.insert(cyclingCategory)
        context.insert(swimmingCategory)
        
        // Create workouts with varied dates and data
        let workouts = [
            // Today
            Workout(type: .strength, startDate: Date().addingTimeInterval(-3600), duration: 45 * 60, calories: 350),
            Workout(type: .running, startDate: Date().addingTimeInterval(-7200), duration: 30 * 60, calories: 400, distance: 5000),
            
            // Yesterday
            Workout(type: .cardio, startDate: Date().addingTimeInterval(-86400), duration: 60 * 60, calories: 600),
            Workout(type: .yoga, startDate: Date().addingTimeInterval(-90000), duration: 75 * 60, calories: 200),
            
            // 2 days ago
            Workout(type: .cycling, startDate: Date().addingTimeInterval(-172800), duration: 90 * 60, calories: 550, distance: 25000),
            Workout(type: .strength, startDate: Date().addingTimeInterval(-176400), duration: 50 * 60, calories: 380),
            
            // 3 days ago
            Workout(type: .running, startDate: Date().addingTimeInterval(-259200), duration: 45 * 60, calories: 450, distance: 8000),
            Workout(type: .swimming, startDate: Date().addingTimeInterval(-262800), duration: 40 * 60, calories: 320),
            
            // 4 days ago
            Workout(type: .cardio, startDate: Date().addingTimeInterval(-345600), duration: 35 * 60, calories: 420),
            Workout(type: .strength, startDate: Date().addingTimeInterval(-349200), duration: 55 * 60, calories: 400),
            
            // 5 days ago
            Workout(type: .running, startDate: Date().addingTimeInterval(-432000), duration: 25 * 60, calories: 280, distance: 4000),
            Workout(type: .yoga, startDate: Date().addingTimeInterval(-435600), duration: 60 * 60, calories: 180),
            
            // 6 days ago
            Workout(type: .cycling, startDate: Date().addingTimeInterval(-518400), duration: 120 * 60, calories: 720, distance: 35000),
            Workout(type: .cardio, startDate: Date().addingTimeInterval(-522000), duration: 50 * 60, calories: 480),
            
            // 1 week ago
            Workout(type: .strength, startDate: Date().addingTimeInterval(-604800), duration: 65 * 60, calories: 450),
            Workout(type: .running, startDate: Date().addingTimeInterval(-608400), duration: 35 * 60, calories: 350, distance: 6000),
            
            // 8 days ago
            Workout(type: .swimming, startDate: Date().addingTimeInterval(-691200), duration: 45 * 60, calories: 360),
            Workout(type: .yoga, startDate: Date().addingTimeInterval(-694800), duration: 90 * 60, calories: 220),
            
            // 9 days ago
            Workout(type: .cardio, startDate: Date().addingTimeInterval(-777600), duration: 40 * 60, calories: 440),
            Workout(type: .strength, startDate: Date().addingTimeInterval(-781200), duration: 70 * 60, calories: 520),
            
            // 10 days ago
            Workout(type: .running, startDate: Date().addingTimeInterval(-864000), duration: 50 * 60, calories: 500, distance: 9000),
            Workout(type: .cycling, startDate: Date().addingTimeInterval(-867600), duration: 80 * 60, calories: 480, distance: 22000)
        ]
        
        // Assign categories to workouts
        let categories = [strengthCategory, runningCategory, cardioCategory, yogaCategory, cyclingCategory, swimmingCategory]
        for (index, workout) in workouts.enumerated() {
            workout.categories = [categories[index % categories.count]]
            context.insert(workout)
        }
        
        try? context.save()
        
        return WorkoutListView()
            .modelContainer(container)
    }
    
    return preview()
}

#Preview("Well Done Sheet") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    // Create a sample workout for the preview
    let sampleWorkout = Workout(
        type: .running,
        startDate: Date().addingTimeInterval(-1800), // 30 minutes ago
        duration: 45 * 60, // 45 minutes
        calories: 425,
        distance: 5500 // 5.5 km
    )
    context.insert(sampleWorkout)
    
    try? context.save()
    
    return WellDoneSheetView(isPresented: .constant(true))
        .modelContainer(container)
}
