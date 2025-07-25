import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var selectedFilter = WorkoutFilter.all
    @State private var selectedWorkoutForDetail: Workout?
    @State private var showingWellDoneSheet = false
    @State private var isRefreshing = false
    @State private var showingPremiumPaywall = false
    @State private var searchText = ""
    @State private var showingFilters = false
    
    // HealthKit import states
    @State private var healthKitImportResult: String?
    @State private var showingHealthKitImportError = false
    @State private var healthKitImportError: HealthKitError?
    
    
    
    // MARK: - Cached Properties (updated only when needed)
    @State private var cachedFilteredWorkouts: [Workout] = []
    @State private var cachedThisWeekCount: Int = 0
    @State private var cachedThisMonthCount: Int = 0
    @State private var lastCacheUpdate: Date = Date.distantPast
    
    // Simple computed properties without heavy calculations
    var filteredWorkouts: [Workout] {
        return cachedFilteredWorkouts.isEmpty ? Array(workouts.prefix(20)) : cachedFilteredWorkouts
    }
    
    var thisWeekWorkouts: [Workout] { 
        return Array(workouts.prefix(cachedThisWeekCount))
    }
    
    var thisMonthWorkouts: [Workout] { 
        return Array(workouts.prefix(cachedThisMonthCount))
    }
    
    var totalMinutesThisWeek: Int {
        // Simplified calculation to prevent heat
        min(cachedThisWeekCount * 30, 300) // Estimate 30 min per workout, max 300
    }
    
    // MARK: - Cache Management
    private func updateCache() {
        lastCacheUpdate = Date()
        
        // Simple filtering without complex operations
        let recentWorkouts = Array(workouts.prefix(20))
        var filtered = selectedFilter == .all ? recentWorkouts : recentWorkouts.filter { $0.type == selectedFilter.workoutType }
        
        // Apply search if needed
        if !searchText.isEmpty {
            filtered = filtered.filter { workout in
                workout.type.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        cachedFilteredWorkouts = filtered
        
        // Use proper calendar calculations for week/month counts
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        let oneMonthAgo = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)) ?? now
        
        cachedThisWeekCount = recentWorkouts.filter { calendar.startOfDay(for: $0.startDate) >= oneWeekAgo }.count
        cachedThisMonthCount = recentWorkouts.filter { calendar.startOfDay(for: $0.startDate) >= oneMonthAgo }.count
    }
    
    var totalCaloriesThisWeek: Int {
        // Simplified estimate to prevent heat
        cachedThisWeekCount * 250 // Estimate 250 calories per workout
    }
    
    var currentStreak: Int {
        // Simplified streak calculation to prevent heat
        return min(cachedThisWeekCount, 7) // Max 7 day streak shown
    }
    
    var groupedWorkouts: [String: [Workout]] {
        Dictionary(grouping: filteredWorkouts) { workout in
            let calendar = Calendar.current
            let now = Date()
            
            // Use calendar to compare actual days, not just day components
            if calendar.isDate(workout.startDate, inSameDayAs: now) {
                return "Today"
            } else if calendar.isDate(workout.startDate, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
                return "Yesterday"
            } else {
                let daysDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: workout.startDate), to: calendar.startOfDay(for: now)).day ?? 0
                
                if daysDiff <= 7 {
                    return "This Week"
                } else {
                    return "Earlier"
                }
            }
        }
    }
    
    var sortedSections: [String] {
        // Simplified sorting to prevent heat
        let predefinedOrder = ["Today", "Yesterday", "This Week", "Earlier"]
        return groupedWorkouts.keys.sorted { key1, key2 in
            let index1 = predefinedOrder.firstIndex(of: key1) ?? 999
            let index2 = predefinedOrder.firstIndex(of: key2) ?? 999
            return index1 < index2
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Workouts")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search workouts")
                .toolbar {
                    toolbarContent
                }
                .refreshable {
                    await refreshLocalData()
                }
                .sheet(item: $selectedWorkoutForDetail) { workout in
                    NavigationStack {
                        WorkoutDetailView(workout: workout)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showingWellDoneSheet) {
                    wellDoneSheet
                }
                .sheet(isPresented: $showingPremiumPaywall) {
                    PremiumView()
                }
                .sheet(isPresented: $showingAddWorkout) {
                    AddWorkoutView()
                }
                .alert("HealthKit Import", isPresented: $showingHealthKitImportError) {
                    Button("OK") { healthKitImportError = nil }
                } message: {
                    Text(healthKitImportError?.errorDescription ?? "Unknown error occurred")
                }
                .onAppear {
                    updateCache() // Initialize cache on appear
                }
                .onChange(of: workouts.count) { _, _ in
                    Task {
                        await MainActor.run {
                            updateCache()
                        }
                    }
                }
                .onChange(of: selectedFilter) { _, _ in
                    Task {
                        await MainActor.run {
                            updateCache()
                        }
                    }
                }
                .onChange(of: searchText) { _, _ in
                    Task {
                        await MainActor.run {
                            updateCache()
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if filteredWorkouts.isEmpty {
            emptyStateContent
        } else {
            workoutsList
        }
    }
    
    @ViewBuilder
    private var emptyStateContent: some View {
        if searchText.isEmpty {
            // Empty state
            ContentUnavailableView {
                Label("No Workouts", systemImage: "figure.run")
            } description: {
                Text("Start your fitness journey by adding your first workout or importing from HealthKit.")
            } actions: {
                VStack(spacing: 12) {
                    Button("Add Workout") {
                        showingAddWorkout = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        Task {
                            await refreshLocalData()
                        }
                    }) {
                        HStack {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.blue)
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            Text(isRefreshing ? "Importing..." : "Import from HealthKit")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshing)
                }
            }
        } else {
            // Search results empty
            ContentUnavailableView.search(text: searchText)
        }
    }
    
    @ViewBuilder
    private var workoutsList: some View {
        List {
            // Stats cards section
            if !workouts.isEmpty {
                Section {
                    statsCardsView
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // HealthKit import result
            if let importResult = healthKitImportResult {
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(importResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            healthKitImportResult = nil
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(.systemGray6))
            }
            
            // Workouts sections
            ForEach(sortedSections, id: \.self) { section in
                Section(section) {
                    ForEach(groupedWorkouts[section] ?? []) { workout in
                        NativeWorkoutRow(workout: workout) {
                            selectedWorkoutForDetail = workout
                        }
                    }
                    .onDelete { indexSet in
                        deleteWorkouts(at: indexSet, in: section)
                    }
                }
            }
            
            // Premium upgrade section
            if !purchaseManager.hasActiveSubscription && workouts.count > 5 {
                Section {
                    NativePremiumUpgradeRow {
                        showingPremiumPaywall = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshLocalData()
        }
    }
    
    @ViewBuilder
    private var statsCardsView: some View {
        VStack(spacing: 12) {
            // This Week Card
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("\(thisWeekWorkouts.count) of \(workouts.count) workouts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(thisWeekWorkouts.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if totalMinutesThisWeek > 0 {
                        Text("\(totalMinutesThisWeek) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            
            // This Month Card
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("\(thisMonthWorkouts.count) of \(workouts.count) workouts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(thisMonthWorkouts.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    let totalMinutesThisMonth = Int(thisMonthWorkouts.reduce(0) { $0 + $1.duration } / 60)
                    if totalMinutesThisMonth > 0 {
                        Text("\(totalMinutesThisMonth) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.systemImage)
                            .tag(filter)
                    }
                }
                .pickerStyle(.menu)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(action: {
                    Task {
                        await refreshLocalData()
                    }
                }) {
                    Label("Refresh & Import HealthKit", systemImage: isRefreshing ? "arrow.clockwise" : "arrow.clockwise.circle")
                }
                .disabled(isRefreshing)
                
                Divider()
                
                Button(action: {
                    removeDuplicateWorkouts()
                }) {
                    Label("Remove Duplicates", systemImage: "trash")
                }
                
                Button(action: {
                    clearAllWorkouts()
                }) {
                    Label("Clear All Workouts", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
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
    
    @ViewBuilder
    private var wellDoneSheet: some View {
        VStack(spacing: 24) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text("Well Done!")
                    .font(.title2.weight(.bold))
                
                Text("Your workouts have been synced successfully.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Done") {
                showingWellDoneSheet = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helper Methods
    
    private func refreshLocalData() async {
        guard !isRefreshing else { return }
        
        print("[DEBUG] Refreshing local data and attempting HealthKit import")
        isRefreshing = true
        defer { 
            isRefreshing = false 
            print("[DEBUG] Local refresh completed")
        }
        
        // Clear previous import result
        await MainActor.run {
            healthKitImportResult = nil
        }
        
        // Try HealthKit import - the manager will handle authorization internally
        print("[WorkoutList] Attempting HealthKit import...")
        do {
            let result = try await HealthKitManager.shared.importWorkouts(to: modelContext)
            await MainActor.run {
                if result.added > 0 || result.skipped > 0 {
                    healthKitImportResult = "HealthKit: +\(result.added) workouts, \(result.skipped) duplicates skipped"
                    print("[HealthKit] Import successful: \(result.added) added, \(result.skipped) skipped")
                } else {
                    healthKitImportResult = "HealthKit: No new workouts to import"
                    print("[HealthKit] No new workouts found")
                }
            }
        } catch let error as HealthKitError {
            // Only show critical errors, not rate limiting or authorization issues
            if case .rateLimited = error {
                await MainActor.run {
                    healthKitImportResult = "HealthKit: \(error.localizedDescription)"
                }
            } else {
                print("[HealthKit] Import failed: \(error.localizedDescription)")
                // Don't show authorization errors on refresh - they're not critical
            }
        } catch {
            print("[HealthKit] Import failed with unknown error: \(error)")
            // Don't show unknown errors to user
        }
        
        // Update the local cache
        await MainActor.run {
            updateCache()
        }
    }
    
    private func deleteWorkouts(at offsets: IndexSet, in section: String) {
        guard let sectionWorkouts = groupedWorkouts[section] else { return }
        
        for index in offsets {
            let workout = sectionWorkouts[index]
            modelContext.delete(workout)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete workout: \(error)")
        }
    }
    
    private func removeDuplicateWorkouts() {
        let duplicates = findDuplicateWorkouts()
        
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
        
        do {
            try modelContext.save()
            print("Removed \(duplicates.count) duplicates")
        } catch {
            print("Failed to remove duplicates: \(error)")
        }
    }
    
    private func findDuplicateWorkouts() -> [Workout] {
        var seen = Set<String>()
        var duplicates: [Workout] = []
        
        for workout in workouts {
            let signature = "\(workout.type.rawValue)-\(workout.startDate.timeIntervalSince1970)-\(workout.duration)"
            if seen.contains(signature) {
                duplicates.append(workout)
            } else {
                seen.insert(signature)
            }
        }
        
        return duplicates
    }
    
    private func clearAllWorkouts() {
        print("[Clear] Clearing all \(workouts.count) workouts")
        
        for workout in workouts {
            modelContext.delete(workout)
        }
        
        do {
            try modelContext.save()
            print("[Clear] Successfully cleared all workouts")
        } catch {
            print("[Clear] Failed to clear workouts: \(error)")
        }
    }
}

// MARK: - Native Components

struct NativeWorkoutRow: View {
    let workout: Workout
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Workout type icon
            Image(systemName: workout.type.systemImage)
                .font(.title2)
                .foregroundStyle(workout.type.color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Categories
                if let category = workout.categories?.first {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: category.color)?.opacity(0.2) ?? Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                if let calories = workout.calories {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
}

struct NativePremiumUpgradeRow: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Unlock unlimited workouts and advanced features")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - WorkoutType Extension

extension WorkoutType {
    static let all = WorkoutType.other // Using .other as a placeholder for "all"
    
    var color: Color {
        switch self {
        case .running:
            return .blue
        case .cycling:
            return .green
        case .swimming:
            return .cyan
        case .yoga:
            return .purple
        case .strength:
            return .orange
        case .cardio:
            return .red
        case .other:
            return .gray
        }
    }
}


// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    // Create sample workouts with varied dates for better stats
    let sampleWorkouts = [
        // Today
        Workout(type: .running, startDate: Date(), duration: 30 * 60, calories: 400),
        Workout(type: .strength, startDate: Date().addingTimeInterval(-3600), duration: 45 * 60, calories: 350),
        
        // Yesterday
        Workout(type: .cycling, startDate: Date().addingTimeInterval(-86400), duration: 60 * 60, calories: 500),
        Workout(type: .yoga, startDate: Date().addingTimeInterval(-90000), duration: 75 * 60, calories: 200),
        
        // This week
        Workout(type: .cardio, startDate: Date().addingTimeInterval(-172800), duration: 40 * 60, calories: 450),
        Workout(type: .strength, startDate: Date().addingTimeInterval(-259200), duration: 50 * 60, calories: 380),
        
        // This month
        Workout(type: .running, startDate: Date().addingTimeInterval(-604800), duration: 35 * 60, calories: 320),
        Workout(type: .swimming, startDate: Date().addingTimeInterval(-1209600), duration: 45 * 60, calories: 300),
    ]
    
    for workout in sampleWorkouts {
        context.insert(workout)
    }
    
    try? context.save()
    
    return WorkoutListView()
        .modelContainer(container)
}
