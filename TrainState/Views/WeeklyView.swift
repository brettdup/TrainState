import SwiftUI
import SwiftData

struct WeeklyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

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
                LazyVStack(spacing: 16) {
                    ForEach(thisWeekWorkouts, id: \.id) { workout in
                        HStack(spacing: 16) {
                            Image(systemName: workout.type.systemImage)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(workout.type.tintColor)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(workout.type.tintColor.opacity(0.15))
                                )
                            Text(workout.type.rawValue)
                                .font(.body.weight(.medium))
                            Spacer()
                            Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .glassCard(cornerRadius: 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("This Week")
    }

    private var thisWeekWorkouts: [Workout] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return workouts.filter { weekInterval.contains($0.startDate) }
    }
}

#Preview {
    NavigationStack {
        WeeklyView()
    }
    .modelContainer(for: [Workout.self], inMemory: true)
}
