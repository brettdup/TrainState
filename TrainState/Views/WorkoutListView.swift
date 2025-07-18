import SwiftUI
import SwiftData
import HealthKit

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddWorkout = false
    @State private var selectedFilter = WorkoutType.all
    @State private var selectedWorkoutForDetail: Workout?
    @State private var showingWellDoneSheet = false
    @State private var isRefreshing = false
    @State private var showingPremiumPaywall = false
    @State private var searchText = ""
    @State private var showingFilters = false
    
    private let healthStore = HKHealthStore()
    
    // Toast feedback state
    @State private var showToast = false
    @State private var toastMessage = ""
    
    // MARK: - Computed Properties
    var filteredWorkouts: [Workout] {
        let filtered = selectedFilter == .all ? workouts : workouts.filter { $0.type == selectedFilter }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { workout in
                workout.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
                workout.categories?.contains { $0.name.localizedCaseInsensitiveContains(searchText) } == true
            }
        }
    }
    
    var groupedWorkouts: [String: [Workout]] {
        Dictionary(grouping: filteredWorkouts) { workout in
            let calendar = Calendar.current
            if calendar.isDateInToday(workout.startDate) {
                return "Today"
            } else if calendar.isDateInYesterday(workout.startDate) {
                return "Yesterday"
            } else if calendar.isDate(workout.startDate, equalTo: Date(), toGranularity: .weekOfYear) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: workout.startDate)
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: workout.startDate)
            }
        }
    }
    
    var sortedSections: [String] {
        let calendar = Calendar.current
        return groupedWorkouts.keys.sorted { key1, key2 in
            // Get the first workout for each group to compare dates
            guard let workouts1 = groupedWorkouts[key1],
                  let workouts2 = groupedWorkouts[key2],
                  let date1 = workouts1.first?.startDate,
                  let date2 = workouts2.first?.startDate else {
                return false
            }
            return date1 > date2
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
                    await refreshHealthData()
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
                Text("Start your fitness journey by adding your first workout.")
            } actions: {
                Button("Add Workout") {
                    showingAddWorkout = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            // Search results empty
            ContentUnavailableView.search(text: searchText)
        }
    }
    
    @ViewBuilder
    private var workoutsList: some View {
        List {
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
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Filter", selection: $selectedFilter) {
                    Label("All", systemImage: "square.stack.3d.up")
                        .tag(WorkoutType.all)
                    
                    ForEach(WorkoutType.allCases.filter { $0 != .all }, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .tag(type)
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
                    Task { await refreshHealthData() }
                }) {
                    Label("Sync with Health", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
                
                Button(action: {
                    removeDuplicateWorkouts()
                }) {
                    Label("Remove Duplicates", systemImage: "trash")
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
    
    private func refreshHealthData() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
            
            await MainActor.run {
                toastMessage = "Workouts synced"
                showToast = true
                
                if workouts.count > 0 {
                    showingWellDoneSheet = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showToast = false
                }
            }
        } catch {
            await MainActor.run {
                toastMessage = "Sync failed"
                showToast = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showToast = false
                }
            }
        }
    }
    
    private func removeDuplicateWorkouts() {
        let duplicates = findDuplicateWorkouts()
        
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
        
        do {
            try modelContext.save()
            toastMessage = "Removed \(duplicates.count) duplicates"
        } catch {
            toastMessage = "Failed to remove duplicates"
        }
        
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
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
}

// MARK: - Native Components

struct NativeWorkoutRow: View {
    let workout: Workout
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
        }
        .buttonStyle(.plain)
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
    
    var systemImage: String {
        switch self {
        case .running:
            return "figure.run"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        case .yoga:
            return "figure.mind.and.body"
        case .strength:
            return "dumbbell.fill"
        case .cardio:
            return "heart.fill"
        case .other:
            return "square.stack.3d.up"
        }
    }
    
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
    
    // Create sample workouts
    let sampleWorkouts = [
        Workout(type: .running, startDate: Date(), duration: 30 * 60, calories: 400),
        Workout(type: .strength, startDate: Date().addingTimeInterval(-3600), duration: 45 * 60, calories: 350),
        Workout(type: .cycling, startDate: Date().addingTimeInterval(-86400), duration: 60 * 60, calories: 500),
        Workout(type: .yoga, startDate: Date().addingTimeInterval(-172800), duration: 75 * 60, calories: 200),
    ]
    
    for workout in sampleWorkouts {
        context.insert(workout)
    }
    
    try? context.save()
    
    return WorkoutListView()
        .modelContainer(container)
}
