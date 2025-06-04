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
    
    // MARK: - Greeting
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        filtersView
                        workoutListView
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
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
            Text("Workout Types")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
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
        VStack(spacing: 16) {
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
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Refresh HealthKit data
        await fetchHealthData()
    }
    
    // MARK: - HealthKit Functions
    
    private func fetchHealthData() async {
        print("Refreshing HealthKit data including workouts...")

        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!
            // Add other types as needed, e.g., HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: typesToRead)
            print("HealthKit authorization granted or already determined for requested types.")
            
            await fetchAndStoreWorkouts()
            
            await fetchStepCount()
            
        } catch {
            print("HealthKit authorization failed or error occurred: \(error.localizedDescription)")
        }
    }
    
    private func fetchAndStoreWorkouts() async {
        print("Starting to fetch and store workouts...")

        // Get the startDate of the most recent workout stored locally
        var latestKnownWorkoutStartDate: Date? = nil
        do {
            var fetchDescriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startDate, order: .reverse)])
            fetchDescriptor.fetchLimit = 1
            if let lastWorkout = try modelContext.fetch(fetchDescriptor).first {
                latestKnownWorkoutStartDate = lastWorkout.startDate
                print("Most recent workout startDate in SwiftData: \(lastWorkout.startDate)")
            } else {
                print("No workouts found in SwiftData. Will fetch all from HealthKit.")
            }
        } catch {
            print("Error fetching latest workout startDate from SwiftData: \(error.localizedDescription)")
            // Proceed without a startDate predicate, fetching all workouts
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let workoutType = HKObjectType.workoutType()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            
            var predicate: NSPredicate? = nil
            if let startDateForPredicate = latestKnownWorkoutStartDate {
                // Fetch workouts that started AFTER our latest known workout.
                // Using a small epsilon to avoid potential floating point comparison issues with dates,
                // and to ensure we don't miss workouts that might have the *exact* same start time if re-imported.
                // The UUID check later will prevent actual duplicates.
                let slightlyLaterStartDate = startDateForPredicate.addingTimeInterval(1) // 1 second later
                predicate = NSPredicate(format: "startDate > %@", slightlyLaterStartDate as NSDate)
                print("HealthKit query will use predicate: startDate > \(slightlyLaterStartDate)")
            } else {
                print("HealthKit query will fetch all workouts (no predicate).")
            }

            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                guard let fetchedWorkouts = samples as? [HKWorkout], error == nil else {
                    print("Error fetching workouts: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume() // Resume on error
                    return
                }

                if fetchedWorkouts.isEmpty {
                    print("No new workouts found in HealthKit.")
                    continuation.resume() // Resume if no workouts
                    return
                }

                print("Fetched \(fetchedWorkouts.count) workouts from HealthKit.")

                Task {
                    await MainActor.run {
                        var newWorkoutsInserted = false
                        for hkWorkout in fetchedWorkouts {
                            // Use FetchDescriptor for optimized duplicate check
                            let workoutUUID = hkWorkout.uuid
                            let workoutStartDate = hkWorkout.startDate
                            let workoutDuration = hkWorkout.duration
                            
                            // First check by UUID
                            var uuidFetchDescriptor = FetchDescriptor<Workout>(
                                predicate: #Predicate { workout in
                                    workout.healthKitUUID == workoutUUID
                                }
                            )
                            
                            // Then check by date and duration if UUID check fails
                            var dateDurationFetchDescriptor = FetchDescriptor<Workout>(
                                predicate: #Predicate { workout in
                                    workout.startDate == workoutStartDate && workout.duration == workoutDuration
                                }
                            )
                            
                            do {
                                // Check UUID first
                                let existingByUUID = try modelContext.fetch(uuidFetchDescriptor)
                                if !existingByUUID.isEmpty {
                                    print("Workout with HKUUID \(hkWorkout.uuid) already exists. Skipping.")
                                    continue
                                }
                                
                                // Then check date and duration
                                let existingByDateDuration = try modelContext.fetch(dateDurationFetchDescriptor)
                                if !existingByDateDuration.isEmpty {
                                    print("Workout with same date and duration already exists. Skipping.")
                                    continue
                                }
                                
                                // If we get here, it's a new workout
                                let newWorkoutType = self.mapHKWorkoutActivityTypeToWorkoutType(hkWorkout.workoutActivityType)
                                
                                let newWorkout = Workout(
                                    type: newWorkoutType,
                                    startDate: hkWorkout.startDate,
                                    duration: hkWorkout.duration,
                                    calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                                    distance: hkWorkout.workoutActivityType == .running ? hkWorkout.totalDistance?.doubleValue(for: .meter()) : nil,
                                    healthKitUUID: hkWorkout.uuid
                                )
                                modelContext.insert(newWorkout)
                                newWorkoutsInserted = true
                                print("Inserting new workout from HealthKit: Type(\(newWorkoutType.rawValue)) - \(newWorkout.startDate) - HKUUID: \(hkWorkout.uuid)")
                            } catch {
                                print("Error checking for existing workout (UUID: \(workoutUUID)): \(error.localizedDescription)")
                            }
                        }
                        
                        if newWorkoutsInserted {
                            do {
                                try modelContext.save()
                                print("Successfully saved context after processing workouts.")
                                // Show well done sheet when new workouts are imported
                                showingWellDoneSheet = true
                            } catch {
                                print("Failed to save model context after processing workouts: \(error.localizedDescription)")
                            }
                        } else {
                             print("No new workouts were inserted, skipping save.")
                        }
                        continuation.resume() // Resume after all processing
                    }
                }
            }
            healthStore.execute(query)
        }
        print("Finished fetching and storing workouts.")
    }

    // Helper function to map HKWorkoutActivityType to your app's WorkoutType
    private func mapHKWorkoutActivityTypeToWorkoutType(_ activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .yoga:
            return .yoga
        case .barre, .coreTraining, .dance, .flexibility, .highIntensityIntervalTraining, .jumpRope, .kickboxing, .pilates, .stairs, .stepTraining, .walking, .elliptical, .handCycling:
            return .cardio
        default:
            print("Unmapped HKWorkoutActivityType: \(activityType.rawValue)")
            return .other
        }
    }

    private func fetchStepCount() async {
        print("Starting to fetch step count...")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                print("Step count type is no longer available in HealthKit.")
                continuation.resume()
                return
            }
            
            let now = Date()
            let startDate = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: stepCountType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    print("Error fetching step count samples: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume() // Resume on error
                    return
                }
                
                let totalSteps = quantitySamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.count()) }
                
                Task { // Ensure UI updates or related logic run on main actor
                    await MainActor.run {
                        print("Total steps today (on refresh): \(totalSteps)")
                        // If you have a @State var for steps, update it here:
                        // self.todayStepCount = totalSteps
                    }
                    continuation.resume() // Resume after processing
                }
            }
            healthStore.execute(query)
        }
        print("Finished fetching step count.")
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(workouts[index])
            }
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            formatter.dateFormat = "'last' EEEE 'at' h:mm a"
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

#Preview {
    WorkoutListView()
        .modelContainer(for: Workout.self, inMemory: true)
} 
