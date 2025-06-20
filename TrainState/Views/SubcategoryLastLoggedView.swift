import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    
    @State private var selectedWorkoutType: WorkoutType = .strength
    @State private var searchText = ""
    @State private var showingFilterOptions = false
    @State private var lastLoggedCache: [UUID: Date] = [:]
    
    private func buildLastLoggedCache() -> [UUID: Date] {
        var cache: [UUID: Date] = [:]
        for workout in workouts {
            guard let subcats = workout.subcategories else { continue }
            for subcat in subcats {
                if let existing = cache[subcat.id] {
                    if workout.startDate > existing {
                        cache[subcat.id] = workout.startDate
                    }
                } else {
                    cache[subcat.id] = workout.startDate
                }
            }
        }
        return cache
    }
    
    private var filteredSubcategories: [WorkoutSubcategory] {
        let relevantCategoryIds = categories
            .filter { $0.workoutType == selectedWorkoutType }
            .map { $0.id }
        
        let typeFiltered = subcategories.filter { subcategory in
            if let category = subcategory.category {
                return relevantCategoryIds.contains(category.id)
            }
            return false
        }
        
        if searchText.isEmpty {
            return typeFiltered
        } else {
            return typeFiltered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func getLastLoggedDate(for subcategory: WorkoutSubcategory) -> Date? {
        lastLoggedCache[subcategory.id]
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never logged" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private func getDaysSinceLastLogged(_ date: Date?) -> Int? {
        guard let date = date else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
    
    private func getStatusColor(for days: Int?) -> Color {
        guard let days = days else { return .gray }
        
        switch days {
        case 0: return .green
        case 1...3: return .blue
        case 4...7: return .orange
        default: return .red
        }
    }
    
    private func getStatusIcon(for days: Int?) -> String {
        guard let days = days else { return "questionmark.circle.fill" }
        
        switch days {
        case 0: return "checkmark.circle.fill"
        case 1...3: return "clock.badge.checkmark.fill"
        case 4...7: return "clock.badge.exclamationmark.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private func getStatusMessage(for days: Int?) -> String {
        guard let days = days else { return "Not tracked yet" }
        
        switch days {
        case 0: return "Worked out today!"
        case 1: return "Yesterday"
        case 2...3: return "\(days) days ago"
        case 4...7: return "\(days) days ago - Consider training soon"
        case 8...14: return "\(days) days ago - Time to get back to it!"
        default: return "\(days) days ago - Been a while!"
        }
    }
    
    private var sortedSubcategories: [WorkoutSubcategory] {
        filteredSubcategories.sorted { sub1, sub2 in
            let date1 = getLastLoggedDate(for: sub1)
            let date2 = getLastLoggedDate(for: sub2)
            
            // If both have dates, compare them (oldest first)
            if let date1 = date1, let date2 = date2 {
                return date1 < date2
            }
            
            // If only one has a date, put the one without date first
            if date1 == nil && date2 != nil {
                return true
            }
            if date1 != nil && date2 == nil {
                return false
            }
            
            // If neither has a date, sort alphabetically
            return sub1.name < sub2.name
        }
    }
    
    private var groupedSubcategories: [(String, [WorkoutSubcategory])] {
        let groups = Dictionary(grouping: sortedSubcategories) { subcategory in
            let days = getDaysSinceLastLogged(getLastLoggedDate(for: subcategory))
            
            if days == nil {
                return "Never Logged"
            } else if days! == 0 {
                return "Today"
            } else if days! <= 3 {
                return "Recent (1-3 days)"
            } else if days! <= 7 {
                return "This Week (4-7 days)"
            } else if days! <= 14 {
                return "Last 2 Weeks"
            } else {
                return "Needs Attention (14+ days)"
            }
        }
        
        let sortOrder = ["Today", "Recent (1-3 days)", "This Week (4-7 days)", "Last 2 Weeks", "Needs Attention (14+ days)", "Never Logged"]
        
        return sortOrder.compactMap { key in
            if let subcategories = groups[key], !subcategories.isEmpty {
                return (key, subcategories)
            }
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02),
                    Color.purple.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header stats
                    HeaderStatsView(
                        selectedType: selectedWorkoutType,
                        subcategories: filteredSubcategories,
                        getLastLoggedDate: getLastLoggedDate,
                        getDaysSinceLastLogged: getDaysSinceLastLogged
                    )
                    
                    // Modern workout type selector
                    ModernWorkoutTypeSelector(selectedType: $selectedWorkoutType)
                    
                    // Search bar
                    SearchBarView(searchText: $searchText)
                    
                    // Grouped exercise cards
                    ForEach(Array(groupedSubcategories.enumerated()), id: \.offset) { index, group in
                        ExerciseGroupSection(
                            title: group.0,
                            subcategories: group.1,
                            getLastLoggedDate: getLastLoggedDate,
                            getDaysSinceLastLogged: getDaysSinceLastLogged,
                            getStatusColor: getStatusColor,
                            getStatusIcon: getStatusIcon,
                            getStatusMessage: getStatusMessage,
                            formatDate: formatDate
                        )
                    }
                    
                    // Bottom spacing
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Exercise Tracking")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.clear, for: .navigationBar)
        .onAppear {
            lastLoggedCache = buildLastLoggedCache()
        }
        .onChange(of: workouts) { _, _ in
            lastLoggedCache = buildLastLoggedCache()
        }
        .onChange(of: subcategories) { _, _ in
            lastLoggedCache = buildLastLoggedCache()
        }
    }
}

// MARK: - Supporting Views

struct HeaderStatsView: View {
    let selectedType: WorkoutType
    let subcategories: [WorkoutSubcategory]
    let getLastLoggedDate: (WorkoutSubcategory) -> Date?
    let getDaysSinceLastLogged: (Date?) -> Int?
    
    private var exercisesNeedingAttention: Int {
        subcategories.filter { subcategory in
            let days = getDaysSinceLastLogged(getLastLoggedDate(subcategory))
            return days == nil || days! > 7
        }.count
    }
    
    private var exercisesLoggedThisWeek: Int {
        subcategories.filter { subcategory in
            let days = getDaysSinceLastLogged(getLastLoggedDate(subcategory))
            return days != nil && days! <= 7
        }.count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Exercise Overview")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(selectedType.rawValue.capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 16) {
                ExerciseStatCard(
                    title: "Total Exercises",
                    value: "\(subcategories.count)",
                    icon: "list.bullet.clipboard.fill",
                    color: .blue
                )
                
                ExerciseStatCard(
                    title: "This Week",
                    value: "\(exercisesLoggedThisWeek)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                ExerciseStatCard(
                    title: "Need Attention",
                    value: "\(exercisesNeedingAttention)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct ExerciseStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct ModernWorkoutTypeSelector: View {
    @Binding var selectedType: WorkoutType
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Workout Type")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        WorkoutTypeChip(
                            type: type,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct WorkoutTypeChip: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void
    
    private var chipColor: Color {
        switch type {
        case .strength: return .purple
        case .cardio: return .blue
        case .running: return .green
        case .cycling: return .cyan
        case .swimming: return .teal
        case .yoga: return .pink
        case .other: return .orange
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconForType(type))
                    .font(.subheadline.weight(.semibold))
                
                Text(type.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isSelected ? chipColor : Color.secondary.opacity(0.1),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
    
    private func iconForType(_ type: WorkoutType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .other: return "sportscourt.fill"
        }
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            TextField("Search exercises...", text: $searchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct ExerciseGroupSection: View {
    let title: String
    let subcategories: [WorkoutSubcategory]
    let getLastLoggedDate: (WorkoutSubcategory) -> Date?
    let getDaysSinceLastLogged: (Date?) -> Int?
    let getStatusColor: (Int?) -> Color
    let getStatusIcon: (Int?) -> String
    let getStatusMessage: (Int?) -> String
    let formatDate: (Date?) -> String
    
    private var sectionColor: Color {
        switch title {
        case "Today": return .green
        case "Recent (1-3 days)": return .blue
        case "This Week (4-7 days)": return .orange
        case "Last 2 Weeks": return .red.opacity(0.8)
        case "Needs Attention (14+ days)": return .red
        case "Never Logged": return .gray
        default: return .blue
        }
    }
    
    private var sectionIcon: String {
        switch title {
        case "Today": return "checkmark.circle.fill"
        case "Recent (1-3 days)": return "clock.badge.checkmark.fill"
        case "This Week (4-7 days)": return "clock.badge.exclamationmark.fill"
        case "Last 2 Weeks": return "exclamationmark.triangle.fill"
        case "Needs Attention (14+ days)": return "exclamationmark.triangle.fill"
        case "Never Logged": return "questionmark.circle.fill"
        default: return "list.bullet"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: sectionIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sectionColor)
                    
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text("\(subcategories.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(sectionColor, in: Capsule())
            }
            .padding(.horizontal, 24)
            
            // Exercise cards
            LazyVStack(spacing: 12) {
                ForEach(subcategories) { subcategory in
                    ExerciseCard(
                        subcategory: subcategory,
                        lastLoggedDate: getLastLoggedDate(subcategory),
                        daysSinceLastLogged: getDaysSinceLastLogged(getLastLoggedDate(subcategory)),
                        statusColor: getStatusColor(getDaysSinceLastLogged(getLastLoggedDate(subcategory))),
                        statusIcon: getStatusIcon(getDaysSinceLastLogged(getLastLoggedDate(subcategory))),
                        statusMessage: getStatusMessage(getDaysSinceLastLogged(getLastLoggedDate(subcategory))),
                        formattedDate: formatDate(getLastLoggedDate(subcategory))
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct ExerciseCard: View {
    let subcategory: WorkoutSubcategory
    let lastLoggedDate: Date?
    let daysSinceLastLogged: Int?
    let statusColor: Color
    let statusIcon: String
    let statusMessage: String
    let formattedDate: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            
            // Exercise info
            VStack(alignment: .leading, spacing: 6) {
                Text(subcategory.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(statusMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(statusColor)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Days indicator
            if let days = daysSinceLastLogged {
                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(statusColor)
                    
                    Text(days == 1 ? "day" : "days")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 2) {
                    Text("—")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.gray)
                    
                    Text("never")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: statusColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Workout.self, WorkoutSubcategory.self, WorkoutCategory.self, configurations: config)

        // Create mock categories and subcategories
        let strengthCategory = WorkoutCategory(name: "Strength", workoutType: .strength)
        let cardioCategory = WorkoutCategory(name: "Cardio", workoutType: .cardio)
        let arms = WorkoutSubcategory(name: "Arms")
        let legs = WorkoutSubcategory(name: "Legs")
        let core = WorkoutSubcategory(name: "Core")
        let back = WorkoutSubcategory(name: "Back")
        let chest = WorkoutSubcategory(name: "Chest")
        let shoulders = WorkoutSubcategory(name: "Shoulders")
        let glutes = WorkoutSubcategory(name: "Glutes")
        let hamstrings = WorkoutSubcategory(name: "Hamstrings")
        let calves = WorkoutSubcategory(name: "Calves")
        let forearms = WorkoutSubcategory(name: "Forearms")
        let biceps = WorkoutSubcategory(name: "Biceps")
        let running = WorkoutSubcategory(name: "Running")
        let cycling = WorkoutSubcategory(name: "Cycling")
        
        // Add subcategories and categories to the container
        container.mainContext.insert(strengthCategory)
        container.mainContext.insert(cardioCategory)
        container.mainContext.insert(arms)
        container.mainContext.insert(legs)
        container.mainContext.insert(running)
        container.mainContext.insert(cycling)
        container.mainContext.insert(core)
        container.mainContext.insert(back)
        container.mainContext.insert(chest)
        container.mainContext.insert(shoulders)
        container.mainContext.insert(glutes)
        container.mainContext.insert(hamstrings)
        container.mainContext.insert(calves)
        container.mainContext.insert(forearms)
        container.mainContext.insert(biceps)

        // Create mock workouts with varied timing
        let workout1 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: 0, to: Date())!, duration: 45)
        workout1.addSubcategory(arms)
        let workout2 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, duration: 60)
        workout2.addSubcategory(legs)
        let workout3 = Workout(type: .cardio, startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, duration: 30)
        workout3.addSubcategory(running)
        let workout4 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, duration: 45)
        workout4.addSubcategory(core)
        let workout5 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -15, to: Date())!, duration: 60)
        workout5.addSubcategory(back)
        let workout6 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, duration: 30)
        workout6.addSubcategory(chest)
        let workout7 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, duration: 45)
        workout7.addSubcategory(shoulders)
        
        container.mainContext.insert(workout1)
        container.mainContext.insert(workout2)
        container.mainContext.insert(workout3)
        container.mainContext.insert(workout4)
        container.mainContext.insert(workout5)
        container.mainContext.insert(workout6)
        container.mainContext.insert(workout7)

        return container
    }()

    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(container)
} 
