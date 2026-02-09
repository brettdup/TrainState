import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    @State private var searchText = ""

    private var strengthWorkouts: [Workout] {
        workouts.filter { $0.type == .strength }
    }

    private var strengthSubcategories: [WorkoutSubcategory] {
        subcategories.filter { $0.category?.workoutType == .strength }
    }

    private var subcategoriesWithLastLogged: [(subcategory: WorkoutSubcategory, lastLogged: Date?)] {
        strengthSubcategories.map { subcategory in
            let lastLogged = strengthWorkouts
                .compactMap { workout -> Date? in
                    let linkedInWorkout = workout.subcategories?.contains(where: { $0.id == subcategory.id }) == true
                    let linkedInExercises = workout.exercises?.contains(where: { $0.subcategory?.id == subcategory.id }) == true
                    return (linkedInWorkout || linkedInExercises) ? workout.startDate : nil
                }
                .max()
            return (subcategory, lastLogged)
        }
        .sorted { lhs, rhs in
            switch (lhs.lastLogged, rhs.lastLogged) {
            case (nil, nil): return lhs.subcategory.name.localizedCaseInsensitiveCompare(rhs.subcategory.name) == .orderedAscending
            case (nil, _): return false
            case (_, nil): return true
            case let (a?, b?): return a > b
            }
        }
    }

    private var allStrengthExercises: [StrengthExerciseLastLogged] {
        var nameByNormalized: [String: String] = [:]
        var subcategoriesByName: [String: Set<String>] = [:]

        for subcategory in strengthSubcategories {
            for template in subcategory.exerciseTemplates ?? [] {
                let displayName = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !displayName.isEmpty else { continue }
                let normalized = normalizedName(displayName)
                nameByNormalized[normalized] = nameByNormalized[normalized] ?? displayName
                subcategoriesByName[normalized, default: []].insert(subcategory.name)
            }
        }

        for workout in strengthWorkouts {
            for exercise in workout.exercises ?? [] {
                let displayName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !displayName.isEmpty else { continue }
                let normalized = normalizedName(displayName)
                nameByNormalized[normalized] = nameByNormalized[normalized] ?? displayName
                if let subcategoryName = exercise.subcategory?.name {
                    subcategoriesByName[normalized, default: []].insert(subcategoryName)
                }
            }
        }

        return nameByNormalized.map { normalized, displayName in
            let lastLogged = strengthWorkouts
                .compactMap { workout -> Date? in
                    let wasTrained = (workout.exercises ?? []).contains {
                        normalizedName($0.name) == normalized
                    }
                    return wasTrained ? workout.startDate : nil
                }
                .max()

            let linkedSubcategories = Array(subcategoriesByName[normalized] ?? [])
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            return StrengthExerciseLastLogged(
                id: normalized,
                name: displayName,
                linkedSubcategories: linkedSubcategories,
                lastLogged: lastLogged
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.lastLogged, rhs.lastLogged) {
            case (nil, nil): return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case (nil, _): return false
            case (_, nil): return true
            case let (a?, b?): return a > b
            }
        }
    }

    private var filteredSubcategories: [(subcategory: WorkoutSubcategory, lastLogged: Date?)] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return subcategoriesWithLastLogged
        }
        return subcategoriesWithLastLogged.filter {
            $0.subcategory.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredExercises: [StrengthExerciseLastLogged] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allStrengthExercises
        }
        return allStrengthExercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.linkedSubcategories.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
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
                    summaryCard

                    if strengthSubcategories.isEmpty {
                        Text("No strength subcategories found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .glassCard(cornerRadius: 32)
                    } else {
                        sectionHeader(title: "Strength Subcategories", count: filteredSubcategories.count)

                        ForEach(filteredSubcategories, id: \.subcategory.id) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.subcategory.name)
                                    .font(.body.weight(.semibold))
                                Text(lastTrainedLine(for: item.lastLogged))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .glassCard(cornerRadius: 32)
                        }

                        sectionHeader(title: "Strength Exercises", count: filteredExercises.count)

                        ForEach(filteredExercises) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name)
                                    .font(.body.weight(.semibold))

                                if !item.linkedSubcategories.isEmpty {
                                    Text(item.linkedSubcategories.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(lastTrainedLine(for: item.lastLogged))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .glassCard(cornerRadius: 32)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Last Trained")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search strength list")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Full Strength List")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(strengthSubcategories.count) subcategories · \(allStrengthExercises.count) exercises")
                .font(.subheadline)

            Text("Includes never-trained entries so gaps are visible.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func lastTrainedLine(for date: Date?) -> String {
        guard let date else { return "Last trained: Never" }
        return "Last trained: \(relativeDateText(for: date)) (\(date.formatted(date: .abbreviated, time: .shortened)))"
    }

    private func relativeDateText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct StrengthExerciseLastLogged: Identifiable {
    let id: String
    let name: String
    let linkedSubcategories: [String]
    let lastLogged: Date?
}

#Preview {
    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, SubcategoryExercise.self], inMemory: true)
}
