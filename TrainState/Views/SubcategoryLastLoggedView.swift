import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    private var strengthSubcategories: [WorkoutSubcategory] {
        subcategories.filter { $0.category?.workoutType == .strength }
    }

    /// Subcategories with their last logged date.
    private var subcategoriesWithLastLogged: [(subcategory: WorkoutSubcategory, lastLogged: Date?)] {
        strengthSubcategories.map { subcategory in
            let lastLogged = workouts
                .filter { workout in
                    workout.subcategories?.contains(where: { $0.id == subcategory.id }) == true
                }
                .map(\.startDate)
                .max()
            return (subcategory, lastLogged)
        }
        .sorted { lhs, rhs in
            switch (lhs.lastLogged, rhs.lastLogged) {
            case (nil, nil): return lhs.subcategory.name < rhs.subcategory.name
            case (nil, _): return false
            case (_, nil): return true
            case let (a?, b?): return a > b
            }
        }
    }

    /// Subcategories grouped by category name for display.
    private var groupedByCategory: [(categoryName: String, items: [(subcategory: WorkoutSubcategory, lastLogged: Date?)])] {
        let grouped = Dictionary(grouping: subcategoriesWithLastLogged) { item in
            item.subcategory.category?.name ?? "Uncategorized"
        }
        return grouped.keys.sorted().map { name in
            (name, grouped[name] ?? [])
        }
    }

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
                    if strengthSubcategories.isEmpty {
                        Text("No subcategories yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .glassCard(cornerRadius: 32)
                    } else {
                        ForEach(groupedByCategory, id: \.categoryName) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(categoryColor(for: group.categoryName))
                                        .frame(width: 8, height: 8)
                                    Text(group.categoryName)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 4)

                                ForEach(group.items, id: \.subcategory.id) { item in
                                    HStack {
                                        Text(item.subcategory.name)
                                            .font(.body)
                                        Spacer()
                                        Text(lastLoggedText(for: item.lastLogged))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(20)
                                    .glassCard(cornerRadius: 32)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Last Trained")
        .navigationBarTitleDisplayMode(.large)
    }

    private func lastLoggedText(for date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func categoryColor(for name: String) -> Color {
        guard let category = subcategories.first(where: { $0.category?.name == name })?.category else { return .secondary }
        return Color(hex: category.color) ?? .secondary
    }
}

#Preview {
    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self], inMemory: true)
}
