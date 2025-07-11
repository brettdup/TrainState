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
                        WorkoutRowView(workout: workout)
                            .onTapGesture {
                                selectedWorkoutForDetail = workout
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingAddWorkout = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await refreshData()
            }
            .sheet(item: $selectedWorkoutForDetail) { workout in
                NavigationStack {
                    WorkoutDetailView(workout: workout)
                }
            }
            .sheet(isPresented: $showingWellDoneSheet) {
                WellDoneSheetView(isPresented: $showingWellDoneSheet)
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
        await MainActor.run {
            isLoading = true
            showToast = true
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
            try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
            let workoutCountAfter = workouts.count
            
            await MainActor.run {
                isLoading = false
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
                isLoading = false
                toastMessage = "Error refreshing workouts"
                showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                }
            }
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
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - WorkoutRowView
struct WorkoutRowView: View {
    let workout: Workout
    
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
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
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
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.quaternary, lineWidth: 0.5)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        .padding(.vertical, 4)
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
}

// MARK: - WellDoneSheet View
struct WellDoneSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                
                VStack(spacing: 8) {
                    Text("Well Done!")
                        .font(.largeTitle.bold())
                    
                    if let latestWorkout = workouts.first {
                        Text("Your \(latestWorkout.type.rawValue) workout has been imported")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                if let latestWorkout = workouts.first {
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Text(formatDuration(latestWorkout.duration))
                                .font(.headline)
                        }
                        
                        if let calories = latestWorkout.calories {
                            VStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                Text("\(Int(calories)) cal")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                Text("Don't forget to categorize it to keep your log organized!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button("Got it!") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
        
        let strengthCategory = WorkoutCategory(name: "Upper Body")
        let runningCategory = WorkoutCategory(name: "Morning Run")
        let cardioCategory = WorkoutCategory(name: "HIIT")
        
        context.insert(strengthCategory)
        context.insert(runningCategory)
        context.insert(cardioCategory)
        
        let workout1 = Workout(
            type: .strength,
            startDate: Date().addingTimeInterval(-3600),
            duration: 45 * 60,
            calories: 350
        )
        workout1.categories = [strengthCategory]
        context.insert(workout1)
        
        let workout2 = Workout(
            type: .running,
            startDate: Date().addingTimeInterval(-86400),
            duration: 30 * 60,
            calories: 400,
            distance: 5000
        )
        workout2.categories = [runningCategory]
        context.insert(workout2)
        
        let workout3 = Workout(
            type: .cardio,
            startDate: Date().addingTimeInterval(-172800),
            duration: 60 * 60,
            calories: 600
        )
        workout3.categories = [cardioCategory]
        context.insert(workout3)
        
        try? context.save()
        
        return WorkoutListView()
            .modelContainer(container)
    }
    
    return preview()
}
