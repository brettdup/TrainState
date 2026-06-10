import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    @State private var selectedTab: StrengthLastTrainedTab = .categories
    @State private var searchText = ""

    private var strengthWorkouts: [Workout] {
        workouts.filter { $0.type == .strength }
    }

    private var strengthSubcategories: [WorkoutSubcategory] {
        subcategories.filter { $0.category?.resolvedWorkoutType == .strength }
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
                    Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.10),
                    ThemeColor.primaryUi02().opacity(colorScheme == .dark ? 0.35 : 0.65),
                    ThemeColor.primaryUi01()
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                GlassEffectContainerWrapper(spacing: 16) {
                    LazyVStack(spacing: 16) {
                        summaryCard
                        tabPicker

                        if strengthSubcategories.isEmpty {
                            emptyStateCard("No strength subcategories found.")
                        } else if selectedTab == .categories {
                            sectionHeader(title: "Strength Categories", count: filteredSubcategories.count)

                            ForEach(filteredSubcategories, id: \.subcategory.id) { item in
                                NavigationLink {
                                    SubcategoryHistoryView(
                                        subcategory: item.subcategory,
                                        workouts: workouts
                                    )
                                } label: {
                                    lastTrainedRow(
                                        title: item.subcategory.name,
                                        subtitle: item.subcategory.category?.name,
                                        lastLogged: item.lastLogged,
                                        color: item.subcategory.category.flatMap { Color(hex: $0.color) } ?? Color.accentColor,
                                        systemImage: "square.grid.2x2"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            sectionHeader(title: "Strength Exercises", count: filteredExercises.count)

                            ForEach(filteredExercises) { item in
                                lastTrainedRow(
                                    title: item.name,
                                    subtitle: item.linkedSubcategories.isEmpty ? nil : item.linkedSubcategories.joined(separator: " · "),
                                    lastLogged: item.lastLogged,
                                    color: Color.accentColor,
                                    systemImage: "dumbbell.fill"
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Last Trained")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search strength list")
    }

    private var tabPicker: some View {
        Picker("Last Trained Tab", selection: $selectedTab) {
            ForEach(StrengthLastTrainedTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(10)
        .glassCard(prominence: .regular)
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Strength Coverage")
                    .font(.headline)
                Text("\(strengthSubcategories.count) categories · \(allStrengthExercises.count) exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Never-trained entries stay visible so gaps are easy to spot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
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

    private func emptyStateCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(prominence: .regular)
    }

    private func lastTrainedRow(
        title: String,
        subtitle: String?,
        lastLogged: Date?,
        color: Color,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(lastTrainedLine(for: lastLogged))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()

            Text(lastLogged == nil ? "Never" : relativeDateText(for: lastLogged!))
                .font(.caption.weight(.bold))
                .foregroundStyle(lastLogged == nil ? Color.secondary : color)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((lastLogged == nil ? Color.secondary : color).opacity(0.12))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard()
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

private enum StrengthLastTrainedTab: String, CaseIterable, Identifiable {
    case categories
    case exercises

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories:
            return "Categories"
        case .exercises:
            return "Exercises"
        }
    }
}

private struct SubcategoryHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let subcategory: WorkoutSubcategory
    let workouts: [Workout]

    private var matchingWorkouts: [Workout] {
        workouts.filter { workout in
            let linkedInWorkout = workout.subcategories?.contains(where: { $0.id == subcategory.id }) == true
            let linkedInExercises = workout.exercises?.contains(where: { $0.subcategory?.id == subcategory.id }) == true
            return linkedInWorkout || linkedInExercises
        }
    }

    private var groupedExercises: [SubcategoryExerciseHistorySummary] {
        var grouped: [String: [LoggedExerciseReference]] = [:]

        for workout in workouts {
            for exercise in workout.exercises ?? [] {
                guard exercise.subcategory?.id == subcategory.id else { continue }
                let displayName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !displayName.isEmpty else { continue }

                let normalized = displayName.lowercased()
                grouped[normalized, default: []].append(
                    LoggedExerciseReference(name: displayName, date: workout.startDate)
                )
            }
        }

        return grouped.compactMap { _, entries in
            guard let canonical = entries.first?.name else { return nil }
            let dates = entries.map(\.date)

            return SubcategoryExerciseHistorySummary(
                id: canonical.lowercased(),
                name: canonical,
                entryCount: entries.count,
                sessionCount: Set(dates.map { $0.timeIntervalSince1970 }).count,
                lastLogged: dates.max()
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.lastLogged, rhs.lastLogged) {
            case let (a?, b?):
                if a == b {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return a > b
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.10),
                    ThemeColor.primaryUi02().opacity(colorScheme == .dark ? 0.35 : 0.65),
                    ThemeColor.primaryUi01()
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    exercisesCard

                    if matchingWorkouts.isEmpty {
                        Text("No workout history for this subcategory yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .glassCard()
                    } else {
                        ForEach(matchingWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }

                                    Text(workout.primaryWorkoutDisplayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let exercises = exercisesSummary(for: workout), !exercises.isEmpty {
                                        Text(exercises)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                                .glassCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .glassEffectContainer(spacing: 16)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(subcategory.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(.headline)

                Text("\(matchingWorkouts.count) logged session\(matchingWorkouts.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let lastWorkout = matchingWorkouts.first {
                    Text("Last trained \(lastWorkout.startDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private func exercisesSummary(for workout: Workout) -> String? {
        let names = (workout.exercises ?? [])
            .filter { $0.subcategory?.id == subcategory.id }
            .map(\.name)

        guard !names.isEmpty else { return nil }
        return names.joined(separator: " · ")
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises")
                    .font(.headline)
                Spacer()
                Text("\(groupedExercises.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if groupedExercises.isEmpty {
                Text("No exercise entries logged for this subcategory yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedExercises) { exercise in
                    NavigationLink {
                        ExerciseInsightsView(
                            exerciseName: exercise.name,
                            subcategoryID: subcategory.id
                        )
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(exercise.entryCount) entries · \(exercise.sessionCount) sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(lastTrainedLine(for: exercise.lastLogged))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
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
}

private struct LoggedExerciseReference {
    let name: String
    let date: Date
}

private struct SubcategoryExerciseHistorySummary: Identifiable {
    let id: String
    let name: String
    let entryCount: Int
    let sessionCount: Int
    let lastLogged: Date?
}

#Preview {
    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, WorkoutExercise.self, SubcategoryExercise.self], inMemory: true)
}
