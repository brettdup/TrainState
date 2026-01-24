import SwiftUI
import SwiftData

struct DeveloperOptionsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section("Data") {
                Button("Seed Sample Workouts") {
                    seedSampleWorkouts()
                }
            }
        }
        .navigationTitle("Developer")
    }

    private func seedSampleWorkouts() {
        let calendar = Calendar.current
        let samples: [(WorkoutType, Int, Double, Double?)] = [
            (.running, 0, 45, 6.2),
            (.strength, 1, 50, nil),
            (.yoga, 2, 30, nil),
            (.cycling, 4, 60, 18.5)
        ]
        for sample in samples {
            let date = calendar.date(byAdding: .day, value: -sample.1, to: Date()) ?? Date()
            let workout = Workout(type: sample.0, startDate: date, duration: sample.2 * 60, distance: sample.3)
            modelContext.insert(workout)
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        DeveloperOptionsView()
    }
    .modelContainer(for: [Workout.self], inMemory: true)
}
