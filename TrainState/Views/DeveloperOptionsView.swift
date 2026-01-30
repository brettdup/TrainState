import SwiftUI
import SwiftData

struct DeveloperOptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        seedSampleWorkouts()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Seed Sample Workouts")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 32)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
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
