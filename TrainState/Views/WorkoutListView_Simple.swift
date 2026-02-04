import SwiftUI
import SwiftData

struct WorkoutListView_Simple: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Workouts: \(workouts.count)")
                    .font(.title)
                    .padding()
                
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.run",
                        description: Text("Your workouts will appear here")
                    )
                } else {
                    List {
                        ForEach(workouts.prefix(10), id: \.id) { workout in
                            VStack(alignment: .leading) {
                                Text(workout.type.rawValue.capitalized)
                                    .font(.headline)
                                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Remove Sync Health Data button and related code
            }
            .navigationTitle("Workouts")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let context = container.mainContext
    context.insert(Workout(type: .running, startDate: .now, duration: 2400, distance: 5200))
    context.insert(Workout(type: .strength, startDate: .now.addingTimeInterval(-86400), duration: 3600, distance: nil))

    return WorkoutListView_Simple()
        .modelContainer(container)
}
