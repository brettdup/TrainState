import SwiftData
import SwiftUI

struct SubcategoryLastLoggedView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var workouts: [Workout]
  @Query private var categories: [WorkoutCategory]
  @Query private var subcategories: [WorkoutSubcategory]

  @State private var selectedWorkoutType: WorkoutType = .strength
  @State private var searchText = ""
  @State private var showingFilterOptions = false
  @State private var lastLoggedCache: [UUID: Date] = [:]

  private func buildLastLoggedCache() -> [UUID: Date] {
    var cache: [UUID: Date] = [:]
    for workout in workouts {
      guard let subcats = workout.subcategories else { continue }
      for subcat in subcats {
        if let existing = cache[subcat.id] {
          if workout.startDate > existing {
            cache[subcat.id] = workout.startDate
          }
        } else {
          cache[subcat.id] = workout.startDate
        }
      }
    }
    return cache
  }

  private var filteredSubcategories: [WorkoutSubcategory] {
    let relevantCategoryIds =
      categories
      .filter { $0.workoutType == selectedWorkoutType }
      .map { $0.id }

    let typeFiltered = subcategories.filter { subcategory in
      if let category = subcategory.category {
        return relevantCategoryIds.contains(category.id)
      }
      return false
    }

    if searchText.isEmpty {
      return typeFiltered
    } else {
      return typeFiltered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
  }

  private func getLastLoggedDate(for subcategory: WorkoutSubcategory) -> Date? {
    lastLoggedCache[subcategory.id]
  }

  private func formatDate(_ date: Date?) -> String {
    guard let date = date else { return "Never logged" }

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

  private func getStatusColor(for days: Int?) -> Color {
    guard let days = days else { return .gray }

    switch days {
    case 0: return .green
    case 1...3: return .blue
    case 4...7: return .orange
    default: return .red
    }
  }

  private func getStatusIcon(for days: Int?) -> String {
    guard let days = days else { return "questionmark.circle.fill" }

    switch days {
    case 0: return "checkmark.circle.fill"
    case 1...3: return "clock.badge.checkmark.fill"
    case 4...7: return "clock.badge.exclamationmark.fill"
    default: return "exclamationmark.triangle.fill"
    }
  }

  private func getStatusMessage(for days: Int?) -> String {
    guard let days = days else { return "Not tracked yet" }

    switch days {
    case 0: return "Worked out today!"
    case 1: return "Yesterday"
    case 2...3: return "\(days) days ago"
    case 4...7: return "\(days) days ago - Consider training soon"
    case 8...14: return "\(days) days ago - Time to get back to it!"
    default: return "\(days) days ago - Been a while!"
    }
  }

  private var sortedSubcategories: [WorkoutSubcategory] {
    filteredSubcategories.sorted { sub1, sub2 in
      let date1 = getLastLoggedDate(for: sub1)
      let date2 = getLastLoggedDate(for: sub2)

      // If both have dates, compare them (oldest first)
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

  private var groupedSubcategories: [(String, [WorkoutSubcategory])] {
    let groups = Dictionary(grouping: sortedSubcategories) { subcategory in
      let days = getDaysSinceLastLogged(getLastLoggedDate(for: subcategory))

      if days == nil {
        return "Never Logged"
      } else if days! == 0 {
        return "Today"
      } else if days! <= 3 {
        return "Recent (1-3 days)"
      } else if days! <= 7 {
        return "This Week (4-7 days)"
      } else if days! <= 14 {
        return "Last 2 Weeks"
      } else {
        return "Needs Attention (14+ days)"
      }
    }

    let sortOrder = [
      "Today", "Recent (1-3 days)", "This Week (4-7 days)", "Last 2 Weeks",
      "Needs Attention (14+ days)", "Never Logged",
    ]

    return sortOrder.compactMap { key in
      if let subcategories = groups[key], !subcategories.isEmpty {
        return (key, subcategories)
      }
      return nil
    }
  }

  var body: some View {
    ZStack {
      // Subtle gradient background
      LinearGradient(
        colors: [
          Color(.systemBackground),
          Color(.systemGroupedBackground),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 28) {
          // Enhanced workout type selector
          ModernWorkoutTypeSelector(selectedType: $selectedWorkoutType)
            .background(
              .regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
            .padding(.top, 8)

          // Enhanced search bar
          SearchBarView(searchText: $searchText)
            .background(
              .regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 20)

          // Exercise groups with enhanced headers
          LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
            ForEach(Array(groupedSubcategories.enumerated()), id: \.offset) { index, group in
              Section(
                header:
                  HStack {
                    Image(systemName: sectionIcon(for: group.0))
                      .font(.title3.weight(.semibold))
                      .foregroundStyle(sectionColor(for: group.0))
                    Text(group.0)
                      .font(.title3.weight(.semibold))
                      .foregroundStyle(.primary)
                    Spacer()
                    Text("\(group.1.count)")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.white)
                      .padding(.horizontal, 10)
                      .padding(.vertical, 4)
                      .background(sectionColor(for: group.0), in: Capsule())
                  }
                  .padding(.horizontal, 20)
                  .padding(.vertical, 10)
                  .background(
                    .regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                  )
                  .shadow(color: .black.opacity(0.02), radius: 3, x: 0, y: 1)
                  .padding(.top, index == 0 ? 0 : 12)
              ) {
                VStack(spacing: 10) {
                  ForEach(group.1) { subcategory in
                    let lastLogged = getLastLoggedDate(for: subcategory)
                    let daysSince = getDaysSinceLastLogged(lastLogged)

                    HStack(spacing: 16) {
                      // Enhanced status indicator
                      ZStack {
                        Circle()
                          .fill(getStatusColor(for: daysSince).opacity(0.12))
                          .frame(width: 48, height: 48)
                        Image(systemName: getStatusIcon(for: daysSince))
                          .font(.system(size: 20, weight: .semibold))
                          .foregroundStyle(getStatusColor(for: daysSince))
                      }

                      // Enhanced exercise info
                      VStack(alignment: .leading, spacing: 6) {
                        Text(subcategory.name)
                          .font(.body.weight(.semibold))
                          .foregroundStyle(.primary)
                        Text(getStatusMessage(for: daysSince))
                          .font(.footnote)
                          .foregroundStyle(.secondary)
                        if let lastLogged = lastLogged {
                          Text(formatDate(lastLogged))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }
                      }

                      Spacer()

                      // Enhanced days indicator
                      if let days = daysSince {
                        VStack(spacing: 2) {
                          Text("\(days)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(getStatusColor(for: daysSince))
                          Text(days == 1 ? "day" : "days")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                          getStatusColor(for: daysSince).opacity(0.08),
                          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                      } else {
                        VStack(spacing: 2) {
                          Text("—")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.tertiary)
                          Text("never")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                          Color.secondary.opacity(0.06),
                          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                      }
                    }
                    .padding(18)
                    .background(
                      .regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
                  }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                  Color(.secondarySystemGroupedBackground),
                  in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .padding(.horizontal, 12)
              }
            }
          }

          Spacer(minLength: 50)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .navigationTitle("Exercise Tracking")
    .navigationBarTitleDisplayMode(.large)
    .onAppear {
      lastLoggedCache = buildLastLoggedCache()
    }
    .onChange(of: workouts) { _, _ in
      lastLoggedCache = buildLastLoggedCache()
    }
    .onChange(of: subcategories) { _, _ in
      lastLoggedCache = buildLastLoggedCache()
    }
  }

  // Helper functions for section styling
  private func sectionColor(for title: String) -> Color {
    switch title {
    case "Today": return .green
    case "Recent (1-3 days)": return .blue
    case "This Week (4-7 days)": return .orange
    case "Last 2 Weeks": return .red.opacity(0.8)
    case "Needs Attention (14+ days)": return .red
    case "Never Logged": return .gray
    default: return .blue
    }
  }

  private func sectionIcon(for title: String) -> String {
    switch title {
    case "Today": return "checkmark.circle.fill"
    case "Recent (1-3 days)": return "clock.badge.checkmark.fill"
    case "This Week (4-7 days)": return "clock.badge.exclamationmark.fill"
    case "Last 2 Weeks": return "exclamationmark.triangle.fill"
    case "Needs Attention (14+ days)": return "exclamationmark.triangle.fill"
    case "Never Logged": return "questionmark.circle.fill"
    default: return "list.bullet"
    }
  }
}

// MARK: - Supporting Views

struct ModernWorkoutTypeSelector: View {
  @Binding var selectedType: WorkoutType

  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Workout Type")
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)
        Spacer()
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(WorkoutType.allCases, id: \.self) { type in
            WorkoutTypeChip(
              type: type,
              isSelected: selectedType == type,
              action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                  selectedType = type
                }
              }
            )
          }
        }
        .padding(.horizontal, 20)
      }
    }
    .padding(.vertical, 18)
  }
}

struct WorkoutTypeChip: View {
  let type: WorkoutType
  let isSelected: Bool
  let action: () -> Void

  private var chipColor: Color {
    switch type {
    case .strength: return .purple
    case .cardio: return .blue
    case .running: return .green
    case .cycling: return .cyan
    case .swimming: return .teal
    case .yoga: return .pink
    case .other: return .orange
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: iconForType(type))
          .font(.subheadline.weight(.semibold))

        Text(type.rawValue.capitalized)
          .font(.subheadline.weight(.semibold))
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(
        isSelected ? chipColor : Color(.tertiarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .foregroundStyle(isSelected ? .white : .primary)
      .shadow(color: isSelected ? chipColor.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
    }
    .buttonStyle(.plain)
    .scaleEffect(isSelected ? 1.02 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isSelected)
  }

  private func iconForType(_ type: WorkoutType) -> String {
    switch type {
    case .strength: return "dumbbell.fill"
    case .cardio: return "heart.fill"
    case .running: return "figure.run"
    case .cycling: return "bicycle"
    case .swimming: return "figure.pool.swim"
    case .yoga: return "figure.yoga"
    case .other: return "sportscourt.fill"
    }
  }
}

struct SearchBarView: View {
  @Binding var searchText: String
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "magnifyingglass")
        .font(.body.weight(.medium))
        .foregroundStyle(isSearchFocused ? Color.accentColor : .secondary)
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

      TextField("Search exercises...", text: $searchText)
        .font(.body)
        .textFieldStyle(.plain)
        .focused($isSearchFocused)

      if !searchText.isEmpty {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
        .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(isSearchFocused ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    )
  }
}

// Preview with realistic test data for visual testing
#Preview {
  // This preview uses a variety of mock categories, subcategories, and workouts
  // with different dates to showcase the modern UI and grouping logic.
  let container: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
      for: Workout.self, WorkoutSubcategory.self, WorkoutCategory.self, configurations: config)

    // Create mock categories
    let strengthCategory = WorkoutCategory(name: "Strength", workoutType: .strength)
    let cardioCategory = WorkoutCategory(name: "Cardio", workoutType: .cardio)
    container.mainContext.insert(strengthCategory)
    container.mainContext.insert(cardioCategory)

    // Create and associate mock subcategories for strength training
    let chest = WorkoutSubcategory(name: "Chest")
    chest.category = strengthCategory
    let back = WorkoutSubcategory(name: "Back")
    back.category = strengthCategory
    let shoulders = WorkoutSubcategory(name: "Shoulders")
    shoulders.category = strengthCategory
    let arms = WorkoutSubcategory(name: "Arms")
    arms.category = strengthCategory
    let legs = WorkoutSubcategory(name: "Legs")
    legs.category = strengthCategory
    let core = WorkoutSubcategory(name: "Core")
    core.category = strengthCategory
    let glutes = WorkoutSubcategory(name: "Glutes")
    glutes.category = strengthCategory
    let hamstrings = WorkoutSubcategory(name: "Hamstrings")
    hamstrings.category = strengthCategory
    let calves = WorkoutSubcategory(name: "Calves")
    calves.category = strengthCategory
    let forearms = WorkoutSubcategory(name: "Forearms")
    forearms.category = strengthCategory
    let biceps = WorkoutSubcategory(name: "Biceps")
    biceps.category = strengthCategory
    let triceps = WorkoutSubcategory(name: "Triceps")
    triceps.category = strengthCategory

    // Cardio subcategories
    let running = WorkoutSubcategory(name: "Running")
    running.category = cardioCategory
    let cycling = WorkoutSubcategory(name: "Cycling")
    cycling.category = cardioCategory

    // Insert all subcategories
    [
      chest, back, shoulders, arms, legs, core, glutes, hamstrings, calves, forearms, biceps,
      triceps, running, cycling,
    ].forEach {
      container.mainContext.insert($0)
    }

    // Create mock workouts with varied timing for strength subcategories
    let workout1 = Workout(
      type: .strength, startDate: Calendar.current.date(byAdding: .day, value: 0, to: Date())!,
      duration: 45)
    workout1.addSubcategory(arms)
    let workout2 = Workout(
      type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
      duration: 60)
    workout2.addSubcategory(legs)
    let workout3 = Workout(
      type: .cardio, startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
      duration: 30)
    workout3.addSubcategory(running)
    let workout4 = Workout(
      type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
      duration: 45)
    workout4.addSubcategory(core)
    let workout5 = Workout(
      type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
      duration: 60)
    workout5.addSubcategory(back)
    let workout6 = Workout(
      type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
      duration: 30)
    workout6.addSubcategory(chest)
    let workout7 = Workout(
      type: .strength, startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
      duration: 45)
    workout7.addSubcategory(shoulders)

    [workout1, workout2, workout3, workout4, workout5, workout6, workout7].forEach {
      container.mainContext.insert($0)
    }

    return container
  }()

  NavigationStack {
    SubcategoryLastLoggedView()
  }
  .modelContainer(container)
}
