import SwiftUI
import SwiftData
import HealthKit

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.startDate, order: .reverse)]) private var workouts: [Workout]
    @State private var showingAddWorkout = false
    @State private var itemsToShow = 30
    @State private var selectedFilter = "Strength"
    @State private var showingWorkoutDetail = false
    @State private var selectedWorkoutForDetail: Workout?
    @State private var showingWellDoneSheet = false
    @State private var isRefreshing = false
    private let healthStore = HKHealthStore()
    
    // Toast feedback state
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isLoading = false
    
    // MARK: - Stats
    var workoutsThisMonth: [Workout] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }
        let endOfMonth: Date = {
            var comps = DateComponents()
            comps.month = 1
            comps.day = -1
            return calendar.date(byAdding: comps, to: startOfMonth) ?? now
        }()
        return workouts.filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
    }
    
    var runningThisMonthCount: Int {
        workoutsThisMonth.filter { $0.type == .running }.count
    }
    
    var strengthThisMonthCount: Int {
        workoutsThisMonth.filter { $0.type == .strength }.count
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
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ColorReflectiveBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        greetingHeader
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
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await refreshData() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh Workouts")
                }
            }
            .overlay(alignment: .top) {
            if showToast || isLoading {
                ToastView(
                    message: isLoading ? "Refreshing…" : toastMessage,
                    isLoading: isLoading
                )
         
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .allowsHitTesting(false)
            }
        }  
            .sheet(item: $selectedWorkoutForDetail) { workout in
                NavigationStack {
                    WorkoutDetailView(workout: workout)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingWellDoneSheet) {
                WellDoneSheetView(isPresented: $showingWellDoneSheet)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
            }
        }
    }
    
    // MARK: - New Homepage Components

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            // User avatar placeholder
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText())
                    .font(.title2.weight(.bold))
                Text("Ready to crush your goals today?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var statsCardsSection: some View {
        HStack(spacing: 8) {
            StatCard(icon: "dumbbell.fill", value: "\(strengthThisMonthCount)/\(daysPassedInCurrentMonth)", color: .orange)
            StatCard(icon: "figure.run", value: "\(runningThisMonthCount)/\(daysPassedInCurrentMonth)", color: .blue)
            StatCard(icon: "calendar", value: "\(workoutsThisMonth.count)", color: .purple)
        }
        .padding(.horizontal)
    }

    private var workoutListSection: some View {
        VStack(spacing: 32) {
            if filteredWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "figure.run",
                    description: Text("Add your first workout!")
                )
                .padding(.top, 40)
            } else {
                // Sectioned by week (optional)
                ForEach(sectionedWorkouts.keys.sorted(by: >), id: \.self) { weekStart in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sectionHeader(for: weekStart))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                        ForEach(sectionedWorkouts[weekStart] ?? []) { workout in
                            Button(action: {
                                selectedWorkoutForDetail = workout
                                showingWorkoutDetail = true
                            }) {
                                WorkoutCardSD(workout: workout)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                if filteredWorkouts.count > itemsToShow {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            itemsToShow += 30
                        }
                    }) {
                        Text("Show More")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // Section workouts by week
    private var sectionedWorkouts: [Date: [Workout]] {
        Dictionary(grouping: filteredWorkouts.prefix(itemsToShow)) { workout in
            Calendar.current.dateInterval(of: .weekOfYear, for: workout.startDate)?.start ?? workout.startDate
        }
    }

    private func sectionHeader(for weekStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Week of \(formatter.string(from: weekStart))"
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
    
    // MARK: - View Components
    
    private var headerView: some View {
        ZStack(alignment: .bottomLeading) {
            // Background layer
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(height: 180)
                .shadow(radius: 2)

            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Total workouts
                HStack {
                    Text("Total Workouts")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(workouts.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)

                // Stats section
                HStack(spacing: 40) {
                    // Strength Stats
                    StatItem(
                        icon: "dumbbell.fill",
                        iconColor: .orange,
                        title: "Strength",
                        value: "\(strengthThisMonthCount)/\(daysPassedInCurrentMonth)"
                    )

                    // Running Stats
                    StatItem(
                        icon: "figure.run",
                        iconColor: .blue,
                        title: "Running",
                        value: "\(runningThisMonthCount)/\(daysPassedInCurrentMonth)"
                    )

                    // Monthly Stats
                    StatItem(
                        icon: "calendar",
                        iconColor: .purple,
                        title: "Monthly",
                        value: "\(workoutsThisMonth.count)"
                    )
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .padding(.horizontal)
    }
    
    private var filtersView: some View {
        VStack(spacing: 12) {
    
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterPill(
                        title: "All Workouts",
                        icon: "figure.mixed.cardio",
                        isSelected: selectedFilter == "All",
                        color: .purple
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = "All"
                        }
                    }
                    
                    FilterPill(
                        title: "Strength",
                        icon: "dumbbell.fill",
                        isSelected: selectedFilter == "Strength",
                        color: .orange
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = "Strength"
                        }
                    }
                    
                    FilterPill(
                        title: "Running",
                        icon: "figure.run",
                        isSelected: selectedFilter == "Running",
                        color: .blue
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = "Running"
                        }
                    }
                    
                    FilterPill(
                        title: "Cardio",
                        icon: "heart.circle.fill",
                        isSelected: selectedFilter == "Cardio",
                        color: .red
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = "Cardio"
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var workoutListView: some View {
        VStack(spacing: 20) {
            ForEach(Array(filteredWorkouts.prefix(itemsToShow).enumerated()), id: \.element.id) { index, workout in
                Button(action: {
                    selectedWorkoutForDetail = workout
                    showingWorkoutDetail = true
                }) {
                    WorkoutCardSD(workout: workout)
                        .padding(.horizontal)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if filteredWorkouts.count > itemsToShow {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        itemsToShow += 30
                    }
                }) {
                    Text("Show More")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .padding(.horizontal)
            }
            
            if filteredWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "figure.run",
                    description: Text("Add your first workout!")
                )
                .padding(.top, 40)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func refreshData() async {
        await MainActor.run {
            isLoading = true
            showToast = true
        }
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Refresh HealthKit data using unified import logic
        print("[UI] Calling unified HealthKit import logic from WorkoutListView.refreshData")
        do {
            try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
        } catch {
            print("[UI] Error importing workouts from HealthKit: \(error.localizedDescription)")
        }
        await MainActor.run {
            isLoading = false
            toastMessage = "Workouts refreshed!"
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showToast = false
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
}

// MARK: - WorkoutCardSD (SwiftData version)
struct WorkoutCardSD: View {
    let workout: Workout
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if !workout.categories.isEmpty {
                categoriesSection
            }
        }
        .background(
            ZStack {
                Color.clear
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.1))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 2)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            iconView
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.headline.weight(.semibold))
                Text(formattedDate(workout.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()

            if workout.type == .running, let distance = workout.distance {
                Text(String(format: "%.1f km", distance / 1000))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)

                    // need an "in" so it says 5km in 32 mins
                    Text("in ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
            }
            
            Text(formatDuration(workout.duration))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var categoriesSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workout.categories) { category in
                        CategoryChip(category: category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 48, height: 48)
            
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }
    
    // MARK: - Helper Properties
    
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
    
    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }
    
    // MARK: - Helper Methods
    
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
            let components = calendar.dateComponents([.hour, .minute], from: date, to: now)
            if let hour = components.hour, hour < 1 {
                if let minute = components.minute, minute < 1 {
                    return "just now"
                }
                if let minute = components.minute, minute == 1 {
                    return "1 minute ago"
                }
                if let minute = components.minute, minute < 60 {
                    return "\(minute) minutes ago"
                }
            }
            formatter.dateFormat = "'today at' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'yesterday at' h:mm a"
            return formatter.string(from: date)
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date > weekAgo {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
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
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)

            Text("Well Done!")
                .font(.largeTitle)
                .fontWeight(.bold)

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

            Button {
                isPresented = false
            } label: {
                Text("Got it!")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
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

// MARK: - Filter Pill Component
struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - StatItem Component
struct StatItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - ToastView
struct ToastView: View {
    let message: String
    var isLoading: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 22, weight: .bold))
            }
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .top)),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: message)
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: Workout.self, inMemory: true)
}
