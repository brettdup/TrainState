import SwiftUI
import SwiftData
import HealthKit

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var itemsToShow = 30
    @State private var selectedFilter = "All"
    @State private var showingWorkoutDetail = false
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
    
    // Pagination state
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    private let itemsPerPage = 10
    
    // Toast feedback state
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isLoading = false
    
    @Namespace private var namespace
    
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
    
    var totalStrengthCount: Int {
        workouts.filter { $0.type == .strength }.count
    }
    
    var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let range = calendar.range(of: .day, in: .month, for: now)!
        return range.count
    }
    
    var daysPassedInCurrentMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.component(.day, from: now)
    }
    
    var filteredWorkouts: [Workout] {
        var result: [Workout]
        
        switch selectedFilter {
        case "Strength":
            result = workouts.filter { $0.type == .strength }
        case "Running":
            result = workouts.filter { $0.type == .running }
        case "Cardio":
            result = workouts.filter { $0.type == .cardio }
        case "All":
            result = Array(workouts)
        default:
            result = Array(workouts)
        }
        
        // Note: Premium limits are now handled in the UI, not here
        // This allows the "Show More" button to work properly for premium users
        
        return result
    }
    
    var displayedWorkouts: [Workout] {
        // For non-premium users, limit to 5 workouts maximum
        if !purchaseManager.hasActiveSubscription {
            return Array(filteredWorkouts.prefix(5))
        }
        
        // For premium users, respect the itemsToShow limit for "Show More" functionality
        return Array(filteredWorkouts.prefix(itemsToShow))
    }
    
    var hasMoreWorkouts: Bool {
        let totalWorkouts: [Workout]
        switch selectedFilter {
        case "Strength":
            totalWorkouts = workouts.filter { $0.type == .strength }
        case "Running":
            totalWorkouts = workouts.filter { $0.type == .running }
        case "Cardio":
            totalWorkouts = workouts.filter { $0.type == .cardio }
        case "All":
            totalWorkouts = Array(workouts)
        default:
            totalWorkouts = Array(workouts)
        }
        return totalWorkouts.count > currentPage * itemsPerPage
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Simple, performant background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        statsCardsSection
                        filtersView
                        workoutListSection
                    }
                    .padding(.top)
                
                }
                .refreshable {
                    await refreshData()
                }
            }
            .padding(.horizontal, 30)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            Task { await refreshData() }
                        }) {
                            Label("Refresh Workouts", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            removeDuplicateWorkouts()
                        }) {
                            Label("Remove Duplicates", systemImage: "trash.fill")
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else if showToast {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .accessibilityLabel("Workout Options")
                }
            }
            .sheet(item: $selectedWorkoutForDetail) { workout in
                NavigationStack {
                    WorkoutDetailView(workout: workout)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingWellDoneSheet) {
                WellDoneSheetView(isPresented: $showingWellDoneSheet)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingPremiumPaywall) {
                WorkoutPremiumPaywallView(
                    isPresented: $showingPremiumPaywall,
                    onPurchase: {
                        Task {
                            // Try subscription first, then fallback to one-time purchase
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
            .onAppear {
                updateCachedData()
            }
            .onChange(of: workouts) { _, _ in
                updateCachedData()
            }
        }
    }
    
    // MARK: - View Components

    private var statsCardsSection: some View {
        HStack(spacing: 12) {
            // Strength Card
            VStack {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("\(strengthThisMonthCount)")
                    .font(.title.bold())
                Text("Strength")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            
            // Running Card
            if #available(iOS 26.0, *) {
                VStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(runningThisMonthCount)")
                        .font(.title.bold())
                    Text("Running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            }
            
            // Total Workouts Card
            VStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("\(workouts.count)")
                    .font(.title.bold())
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            
            // Monthly Card
            VStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("\(workoutsThisMonth.count)")
                    .font(.title.bold())
                Text("This Month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)

        }.padding(.horizontal, 18)

    }

    private var filtersView: some View {
        let filterSet: [String] = ["All", "Strength", "Running", "Cardio"]
        
        return HStack(spacing: 16) {
            ForEach(filterSet, id: \.self) { item in
                Button(action: {
                    withAnimation() {
                        selectedFilter = item
                        currentPage = 1 // Reset pagination when filter changes
                    }
                }) {
                    Image(systemName: iconName(for: item))
                        .frame(width: 80.0, height: 80.0)
                        .font(.system(size: 36))
                        .foregroundColor(selectedFilter == item ? .blue : .primary)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedFilter == item ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }.padding(.horizontal, 20)
    }
    
    private func iconName(for filter: String) -> String {
        switch filter {
        case "All": return "square.grid.2x2.fill"
        case "Strength": return "dumbbell.fill"
        case "Running": return "figure.run"
        case "Cardio": return "heart.circle.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    private var workoutListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("\(filteredWorkouts.count) Workouts")
                    .font(.title2.weight(.bold))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            
            // Workouts
            LazyVStack(spacing: 12) {
                ForEach(displayedWorkouts) { workout in
                    WorkoutRow(workout: workout)
                        .onTapGesture {
                            selectedWorkoutForDetail = workout
                        }
                }
            }
            
            // Show More Button at the bottom
            if purchaseManager.hasActiveSubscription && filteredWorkouts.count > itemsToShow {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        itemsToShow += 10
                    }
                }) {
                    Text("Show More")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Premium Paywall Button
            if !purchaseManager.hasActiveSubscription && workouts.count > 5 {
                Button(action: {
                    showingPremiumPaywall = true
                }) {
                    Text("Upgrade to Premium to See More")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Greeting
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    // MARK: - Helper Functions
    
    private func removeDuplicateWorkouts() {
        let allWorkouts = workouts
        var seenIDs = Set<UUID>()
        var duplicatesToDelete: [Workout] = []
        
        for workout in allWorkouts {
            if seenIDs.contains(workout.id) {
                duplicatesToDelete.append(workout)
            } else {
                seenIDs.insert(workout.id)
            }
        }
        
        print("Found \(duplicatesToDelete.count) duplicate workouts to remove")
        
        for duplicate in duplicatesToDelete {
            modelContext.delete(duplicate)
        }
        
        do {
            try modelContext.save()
            print("Successfully removed duplicate workouts")
        } catch {
            print("Error removing duplicates: \(error)")
        }
    }
    
    private func refreshData() async {
        await MainActor.run {
            isLoading = true
            showToast = true
        }
        
        print("[UI] Calling unified HealthKit import logic from WorkoutListView.refreshData")
        do {
            let workoutCountBefore = workouts.count
            try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
            let workoutCountAfter = workouts.count
            
            await MainActor.run {
                isLoading = false
                toastMessage = "Workouts refreshed!"
                showToast = true
                
                // Show well done sheet if new workouts were imported
                if workoutCountAfter > workoutCountBefore {
                    showingWellDoneSheet = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                }
            }
        } catch {
            print("[UI] Error importing workouts from HealthKit: \(error.localizedDescription)")
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
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(workouts[index])
            }
            try? modelContext.save()
        }
    }
    
    private func loadMoreWorkouts() {
        isLoadingMore = true
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentPage += 1
            isLoadingMore = false
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
}

// MARK: - Simple Workout Row
struct WorkoutRow: View {
    let workout: Workout
    
    var body: some View {
        workoutCardView()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: iconColor.opacity(0.1), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(iconColor.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch workout.type {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.circle.fill"
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
            formatter.dateFormat = "'today at' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'yesterday at' h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    @ViewBuilder
    private func workoutCardView() -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.type.rawValue)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(workout.startDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let firstCategory = workout.categories?.first {
                        Text(firstCategory.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(iconColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(iconColor.opacity(0.1))
                            )
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if workout.type == .running, let distance = workout.distance {
                    Text(String(format: "%.1f km", distance / 1000))
                        .font(.caption.weight(.medium))
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(iconColor.opacity(0.1))
                        )
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - WellDoneSheet View
struct WellDoneSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Well Done!")
                .font(.largeTitle.bold())
            
            if let latestWorkout = workouts.first {
                VStack(spacing: 12) {
                    Text("Your \(latestWorkout.type.rawValue) workout has been added")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "clock.fill")
                                .font(.title2)
                            Text(formatDuration(latestWorkout.duration))
                                .font(.headline)
                        }
                        
                        if let calories = latestWorkout.calories {
                            VStack {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                Text("\(Int(calories)) cal")
                                    .font(.headline)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Text("Don't forget to categorize it to keep your log organized!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Got it!") {
                isPresented = false
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
        .background(.regularMaterial)
        .cornerRadius(20)
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
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "infinity.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Unlock Unlimited Workouts")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        
                        Text("View all your workouts without limits and access premium features")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Features
                    VStack(spacing: 20) {
                        WorkoutFeatureRow(
                            icon: "infinity",
                            title: "Unlimited Workouts",
                            description: "View all your workouts without any restrictions"
                        )
                        WorkoutFeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Advanced Analytics",
                            description: "Get detailed insights into your fitness progress"
                        )
                        WorkoutFeatureRow(
                            icon: "folder.fill",
                            title: "Premium Categories",
                            description: "Access to unlimited custom categories and subcategories"
                        )
                        WorkoutFeatureRow(
                            icon: "icloud.fill",
                            title: "Cloud Sync",
                            description: "Sync your data across all your devices"
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Purchase Button
                    Button(action: onPurchase) {
                        Text("Unlock Unlimited - $1.99")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

private struct WorkoutFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self, WorkoutRoute.self,
        configurations: config
    )
    
    WorkoutListView()
        .modelContainer(container)
}
