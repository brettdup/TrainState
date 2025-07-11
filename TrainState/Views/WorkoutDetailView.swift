import MapKit
import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Bindable var workout: Workout
  @State private var isEditingCategorySheet = false
  @State private var showRouteSheet = false
  @State private var decodedRoute: [CLLocation] = []
  @State private var scrollOffset: CGFloat = 0

  @Query private var categories: [WorkoutCategory]

  var body: some View {
    ZStack {
      // Modern gradient background with depth
      backgroundGradient
        .ignoresSafeArea()

      // Main content
      GeometryReader { geometry in
        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            // Hero section with workout type and key info
            heroSection
              .padding(.top, 20)
              .padding(.bottom, 32)

            // Content cards in natural flow
            contentSection
              .padding(.bottom, 100)  // Space for floating buttons
          }
          .background(
            GeometryReader { geo in
              Color.clear
                .preference(
                  key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
            }
          )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
          scrollOffset = value
        }
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        // Dynamic title that appears on scroll
        Text(workout.type.rawValue)
          .font(.headline.weight(.semibold))
          .opacity(scrollOffset < -50 ? 1 : 0)
          .animation(.easeInOut(duration: 0.2), value: scrollOffset)
      }
    }
    .sheet(isPresented: $isEditingCategorySheet) {
      NavigationStack {
        CategoryAndSubcategorySelectionView(
          selectedCategories: Binding(
            get: { workout.categories ?? [] },
            set: { newCategories in
              print("DEBUG: Setting categories on workout - Count: \(newCategories.count)")
              workout.categories = newCategories
              // Ensure context save
              try? modelContext.save()
            }
          ),
          selectedSubcategories: Binding(
            get: { workout.subcategories ?? [] },
            set: { newSubcategories in
              print("DEBUG: Setting subcategories on workout - Count: \(newSubcategories.count)")
              
              // Debug: Print subcategory details
              for sub in newSubcategories {
                print("DEBUG: Subcategory being set: \(sub.name) (ID: \(sub.id), persistentModelID: \(sub.persistentModelID))")
              }
              
              // Ensure subcategories are in the same context as the workout
              var validSubcategories: [WorkoutSubcategory] = []
              for selectedSubcategory in newSubcategories {
                let id = selectedSubcategory.id
                let descriptor = FetchDescriptor<WorkoutSubcategory>(
                  predicate: #Predicate { $0.id == id }
                )
                if let subcategory = try? modelContext.fetch(descriptor).first {
                  validSubcategories.append(subcategory)
                  print("DEBUG: Found subcategory in context: \(subcategory.name)")
                } else {
                  print("DEBUG: Subcategory \(selectedSubcategory.name) not found in context!")
                }
              }
              
              workout.subcategories = validSubcategories
              print("DEBUG: Final subcategories set: \(validSubcategories.count)")
              
              // Ensure context save
              try? modelContext.save()
              
              // Debug: Verify after save
              print("DEBUG: After save - Subcategories: \(workout.subcategories?.count ?? 0)")
              if let subcategories = workout.subcategories {
                for sub in subcategories {
                  print("DEBUG: Subcategory after save: \(sub.name)")
                }
              }
            }
          ),
          workoutType: workout.type
        )
      }
    }
    .sheet(isPresented: $showRouteSheet) {
      if workout.type == .running {
        RunningMapAndStatsCard(
          route: decodedRoute, duration: workout.duration, distance: workout.distance)
      }
    }
  }

  // MARK: - Background
  private var backgroundGradient: some View {
    // Simple, performant background
    Color(.systemBackground)
  }

  // MARK: - Hero Section
  private var heroSection: some View {
    VStack(spacing: 20) {
      // Main workout info in a more compact layout
      HStack(spacing: 16) {
        // Workout icon
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [
                  workoutTypeColor.opacity(0.15),
                  workoutTypeColor.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 56, height: 56)

          Image(systemName: WorkoutTypeHelper.iconForType(workout.type))
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(workoutTypeColor)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(workout.type.rawValue)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)

          Text(DateFormatHelper.friendlyDateTime(workout.startDate))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      // Key metrics - different layouts based on available data
      if let calories = workout.calories {
        // Compact 3-column layout when calories are available
        compactMetricsLayout
      } else {
        // Minimal 2-column layout when no calories
        minimalMetricsLayout
      }
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Compact Metrics Layout (with calories)
  private var compactMetricsLayout: some View {
    HStack(spacing: 12) {
      // Duration
      CompactMetricCard(
        icon: "clock.fill",
        value: DurationFormatHelper.formatDuration(workout.duration),
        color: .blue
      )

      // Calories
      if let calories = workout.calories {
        CompactMetricCard(
          icon: "flame.fill",
          value: "\(Int(calories))",
          color: .orange
        )
      }

      // Distance or Date (whichever is more relevant)
      if let distance = workout.distance {
        CompactMetricCard(
          icon: "figure.walk",
          value: String(format: "%.1f km", distance / 1000),
          color: .green
        )
      } else {
        CompactMetricCard(
          icon: "calendar",
          value: DateFormatHelper.formattedDate(workout.startDate),
          color: .purple
        )
      }
    }
  }

  // MARK: - Minimal Metrics Layout (without calories)
  private var minimalMetricsLayout: some View {
    HStack(spacing: 16) {
      // Duration
      MinimalMetricCard(
        icon: "clock.fill",
        value: DurationFormatHelper.formatDuration(workout.duration),
        color: .blue
      )

      // Distance or Date
      if let distance = workout.distance {
        MinimalMetricCard(
          icon: "figure.walk",
          value: String(format: "%.1f km", distance / 1000),
          color: .green
        )
      } else {
        MinimalMetricCard(
          icon: "calendar",
          value: DateFormatHelper.formattedDate(workout.startDate),
          color: .purple
        )
      }
    }
  }

  // MARK: - Content Section
  private var contentSection: some View {
    VStack(spacing: 32) {
      if workout.type == .running {
        if let route = workout.route?.decodedRoute, !route.isEmpty {
          RunningMapAndStatsCard(
            route: route,
            duration: workout.duration,
            distance: workout.distance
          )
          .onAppear {
            print("[WorkoutDetail] Workout type: \(workout.type)")
            print("[WorkoutDetail] Has route: \(workout.route != nil)")
            print("[WorkoutDetail] Route points: \(route.count)")
          }
        } else {
          Text("No route data available for this workout")
            .font(.headline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
            )
            .onAppear {
              print("[WorkoutDetail] Workout type: \(workout.type)")
              print("[WorkoutDetail] Has route: \(workout.route != nil)")
              print("[WorkoutDetail] Route points: 0")
            }
        }
      }

      // Categories section
      categoriesSection

      // Notes section (if available)
      if let notes = workout.notes, !notes.isEmpty {
        NotesSection(notes: notes)
      }
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Categories Section
  private var categoriesSection: some View {
    VStack(alignment: .leading, spacing: 24) {
      // Header with edit button
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Categories & Subcategories")
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)

          Text("Organize your workout")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if !(workout.categories?.isEmpty ?? true) || !(workout.subcategories?.isEmpty ?? true) {
          Button(action: { isEditingCategorySheet = true }) {
            Image(systemName: "pencil.circle.fill")
              .font(.system(size: 28))
              .foregroundStyle(.blue)
              .background(
                Circle()
                  .fill(.ultraThinMaterial)
                  .frame(width: 32, height: 32)
              )
          }
          .buttonStyle(ScaleButtonStyle())
        }
      }

      // Content
      if (workout.categories?.isEmpty ?? true) && (workout.subcategories?.isEmpty ?? true) {
        AddCategoriesButton(action: { isEditingCategorySheet = true })
      } else {
        VStack(spacing: 20) {
          // Categories section
          if let categories = workout.categories, !categories.isEmpty {
            CategoriesGroup(title: "Categories", items: categories)
          }

          // Subcategories section
          if let subcategories = workout.subcategories, !subcategories.isEmpty {
            SubcategoriesGroup(title: "Subcategories", items: subcategories)
          }
        }
      }
    }
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: .primary.opacity(0.05), radius: 16, y: 8)
    )
  }

  // MARK: - Helpers
  private var workoutTypeColor: Color {
    switch workout.type {
    case .strength: return .purple
    case .cardio: return .red
    case .yoga: return .mint
    case .running: return .blue
    case .cycling: return .green
    case .swimming: return .cyan
    case .other: return .orange
    }
  }
}

// MARK: - Supporting Views

private struct MetricCard: View {
  let icon: String
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(color)

      VStack(spacing: 4) {
        Text(value)
          .font(.title3.weight(.bold))
          .foregroundStyle(.primary)

        Text(title)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: 100)
    .padding(.vertical, 20)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: color.opacity(0.1), radius: 8, y: 4)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(color.opacity(0.2), lineWidth: 1)
    )
  }
}

private struct AddCategoriesButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 16) {
        Image(systemName: "folder.badge.plus")
          .font(.system(size: 40, weight: .medium))
          .foregroundStyle(.blue)

        VStack(spacing: 8) {
          Text("Add Categories")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)

          Text("Organize this workout with categories and exercises")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 40)
      .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
              .strokeBorder(
                Color.blue.opacity(0.3),
                style: StrokeStyle(
                  lineWidth: 2,
                  lineCap: .round,
                  dash: [8, 4]
                )
              )
          )
      )
    }
    .buttonStyle(ScaleButtonStyle())
  }
}

private struct NotesSection: View {
  let notes: String

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Notes")
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)

          Text("Additional workout details")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "note.text")
          .font(.system(size: 24))
          .foregroundStyle(.orange)
      }

      Text(notes)
        .font(.body)
        .foregroundStyle(.primary)
        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: .primary.opacity(0.05), radius: 16, y: 8)
    )
  }
}

private struct CategoriesGroup: View {
  let title: String
  let items: [WorkoutCategory]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Section header
      HStack {
        Image(systemName: "tag.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.blue)

        Text(title)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)

        Spacer()

        Text("\(items.count)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(.ultraThinMaterial)
          )
      }

      // Categories grid
      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 12),
          GridItem(.flexible(), spacing: 12),
        ], spacing: 12
      ) {
        ForEach(items) { category in
          CategoryCard(category: category)
        }
      }
    }
  }
}

private struct SubcategoriesGroup: View {
  let title: String
  let items: [WorkoutSubcategory]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Section header
      HStack {
        Image(systemName: "tag")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.green)

        Text(title)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)

        Spacer()

        Text("\(items.count)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(.ultraThinMaterial)
          )
      }
      // Subcategories chips in a wrapping layout
      if !items.isEmpty {
        WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
          ForEach(items) { subcategory in
            SubcategoryChip(subcategory: subcategory)
          }
        }
        .padding(.top, 4)
      }
    }
  }
}

private struct CategoryCard: View {
  let category: WorkoutCategory

  var body: some View {
    let color = Color(hex: category.color) ?? .blue

    VStack(spacing: 12) {
      // Icon with background
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [
                color.opacity(0.2),
                color.opacity(0.1),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 48, height: 48)

        Image(systemName: "tag.fill")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(color)
      }

      // Category name
      Text(category.name)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(color.opacity(0.2), lineWidth: 1)
        )
    )
    .shadow(color: color.opacity(0.1), radius: 8, y: 4)
  }
}

private struct CompactMetricCard: View {
  let icon: String
  let value: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(color)

      Text(value)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(0.15), lineWidth: 1)
        )
    )
  }
}

private struct MinimalMetricCard: View {
  let icon: String
  let value: String
  let color: Color

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(color)

      Text(value)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(color.opacity(0.15), lineWidth: 1)
        )
    )
  }
}

// ScaleButtonStyle is already defined in Components/ScaleButtonStyle.swift

// MARK: - Scroll Offset Preference
private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try! ModelContainer(for: Workout.self, configurations: config)
  // Create sample categories
  let category1 = WorkoutCategory(name: "Push", color: "#E53935", workoutType: .strength)
  let category2 = WorkoutCategory(name: "Pull", color: "#1E88E5", workoutType: .strength)
  // Create sample subcategories
  let sub1 = WorkoutSubcategory(name: "Bench Press")
  let sub2 = WorkoutSubcategory(name: "Incline Press")
  let sub3 = WorkoutSubcategory(name: "Pull-ups")
  let sub4 = WorkoutSubcategory(name: "Rows")
  // Assign categories to subcategories (optional, for relationship integrity)
  sub1.category = category1
  sub2.category = category1
  sub3.category = category2
  sub4.category = category2
  // Create a workout with categories and subcategories
  let workout = Workout(
    type: .strength,
    duration: 3600,
    calories: 500,
    distance: 2000,
    notes: "Felt strong today. Focused on form.",
    categories: [category1, category2],
    subcategories: [sub1, sub2, sub3, sub4]
  )
  return NavigationStack {
    WorkoutDetailView(workout: workout)
  }
  .modelContainer(container)
}
