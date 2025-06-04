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
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(WorkoutType.allCases, id: \.self) { type in
                            Button(action: { selectedWorkoutType = type }) {
                                Text(type.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedWorkoutType == type ? Color.blue : Color.secondary.opacity(0.1))
                                    )
                                    .foregroundColor(selectedWorkoutType == type ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            ForEach(sortedSubcategories) { subcategory in
                let lastLoggedDate = getLastLoggedDate(for: subcategory)
                let daysSinceLastLogged = getDaysSinceLastLogged(lastLoggedDate)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subcategory.name)
                            .font(.headline)
                        
                        Text(formatDate(lastLoggedDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let days = daysSinceLastLogged {
                        Text("\(days) days ago")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(days > 7 ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                            )
                            .foregroundColor(days > 7 ? .red : .green)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Last Logged")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
} 