import SwiftUI
import SwiftData

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            WeeklyView()
                .navigationTitle("Calendar")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    return CalendarView()
        .modelContainer(container)
}
