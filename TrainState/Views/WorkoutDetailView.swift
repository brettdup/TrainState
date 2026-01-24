import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout

    var body: some View {
        Form {
            Section("Summary") {
                Label(workout.type.rawValue, systemImage: workout.type.systemImage)
                    .foregroundStyle(workout.type.tintColor)
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                if workout.duration > 0 {
                    Text("Duration: \(formattedDuration(workout.duration))")
                }
                if let distance = workout.distance, distance > 0 {
                    Text("Distance: \(distance, format: .number.precision(.fractionLength(1))) km")
                }
                if let calories = workout.calories, calories > 0 {
                    Text("Calories: \(Int(calories)) kcal")
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            if let categories = workout.categories, !categories.isEmpty {
                Section("Categories") {
                    ForEach(categories) { category in
                        Text(category.name)
                    }
                }
            }
        }
        .navigationTitle("Workout")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let workout = Workout(type: .running, startDate: .now, duration: 2700, distance: 5.2)
    container.mainContext.insert(workout)
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
