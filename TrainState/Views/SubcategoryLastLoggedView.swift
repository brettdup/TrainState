import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @Query private var subcategories: [WorkoutSubcategory]
    
    @State private var selectedWorkoutType: WorkoutType = .strength
    
    private var filteredSubcategories: [WorkoutSubcategory] {
        subcategories.filter { subcategory in
            subcategory.category?.workoutType == selectedWorkoutType
        }
    }
    
    private func getLastLoggedDate(for subcategory: WorkoutSubcategory) -> Date? {
        workouts
            .filter { workout in
                workout.subcategories.contains(where: { $0.id == subcategory.id })
            }
            .sorted { $0.startDate > $1.startDate }
            .first?
            .startDate
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        
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
    
    private var sortedSubcategories: [WorkoutSubcategory] {
        filteredSubcategories.sorted { sub1, sub2 in
            let date1 = getLastLoggedDate(for: sub1)
            let date2 = getLastLoggedDate(for: sub2)
            
            // If both have dates, compare them
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
    
    var body: some View {
        ZStack {
            ColorReflectiveBackground()
            ScrollView {
                VStack(spacing: 20) {
                    // Chip selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(WorkoutType.allCases, id: \.self) { type in
                                Button(action: { selectedWorkoutType = type }) {
                                    Text(type.rawValue)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedWorkoutType == type ? Color.accentColor : Color.secondary.opacity(0.12))
                                        )
                                        .foregroundColor(selectedWorkoutType == type ? .white : .primary)
                                        .shadow(color: selectedWorkoutType == type ? Color.accentColor.opacity(0.18) : .clear, radius: 4, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // Subcategory cards
                    ForEach(sortedSubcategories) { subcategory in
                        let lastLoggedDate = getLastLoggedDate(for: subcategory)
                        let daysSinceLastLogged = getDaysSinceLastLogged(lastLoggedDate)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(subcategory.name)
                                    .font(.headline)
                                Spacer()
                                if let days = daysSinceLastLogged {
                                    Text("\(days) days ago")
                                        .font(.caption2)
                                        .foregroundColor(days > 7 ? .red : .green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background((days > 7 ? Color.red.opacity(0.12) : Color.green.opacity(0.12)).opacity(0.7))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(formatDate(lastLoggedDate))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.primary.opacity(0.07), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                    Spacer(minLength: 12)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Last Logged")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        // .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Workout.self, WorkoutSubcategory.self, WorkoutCategory.self, configurations: config)

        // Create mock categories and subcategories
        let strengthCategory = WorkoutCategory(name: "Strength", workoutType: .strength)
        let cardioCategory = WorkoutCategory(name: "Cardio", workoutType: .cardio)
        let arms = WorkoutSubcategory(name: "Arms", category: strengthCategory)
        let legs = WorkoutSubcategory(name: "Legs", category: strengthCategory)
        let core = WorkoutSubcategory(name: "Core", category: strengthCategory)
        let back = WorkoutSubcategory(name: "Back", category: strengthCategory)
        let chest = WorkoutSubcategory(name: "Chest", category: strengthCategory)
        let shoulders = WorkoutSubcategory(name: "Shoulders", category: strengthCategory)
        let glutes = WorkoutSubcategory(name: "Glutes", category: strengthCategory)
        let hamstrings = WorkoutSubcategory(name: "Hamstrings", category: strengthCategory)
        let calves = WorkoutSubcategory(name: "Calves", category: strengthCategory)
        let forearms = WorkoutSubcategory(name: "Forearms", category: strengthCategory)
        let biceps = WorkoutSubcategory(name: "Biceps", category: strengthCategory)
        let running = WorkoutSubcategory(name: "Running", category: cardioCategory)
        let cycling = WorkoutSubcategory(name: "Cycling", category: cardioCategory)

        // Add subcategories and categories to the container
        container.mainContext.insert(strengthCategory)
        container.mainContext.insert(cardioCategory)
        container.mainContext.insert(arms)
        container.mainContext.insert(legs)
        container.mainContext.insert(running)
        container.mainContext.insert(cycling)

        // Create mock workouts
        let workout1 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, duration: 45, subcategories: [arms])
        let workout2 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, duration: 60, subcategories: [legs])
        let workout3 = Workout(type: .cardio, startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, duration: 30, subcategories: [running])
        let workout4 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, duration: 45, subcategories: [core])
        let workout5 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, duration: 60, subcategories: [back])
        let workout6 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, duration: 30, subcategories: [chest])
        let workout7 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, duration: 45, subcategories: [shoulders])
        let workout8 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, duration: 60, subcategories: [glutes])
        let workout9 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, duration: 30, subcategories: [hamstrings])
        let workout10 = Workout(type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, duration: 45, subcategories: [calves])
        container.mainContext.insert(workout1)
        container.mainContext.insert(workout2)
        container.mainContext.insert(workout3)
        container.mainContext.insert(workout4)
        container.mainContext.insert(workout5)
        container.mainContext.insert(workout6)
        container.mainContext.insert(workout7)
        container.mainContext.insert(workout8)
        container.mainContext.insert(workout9)
        container.mainContext.insert(workout10)

        return container
    }()

    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(container)
} 
