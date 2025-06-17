import SwiftUI
import SwiftData
import MapKit

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout
    @State private var isEditing = false
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
                            .padding(.bottom, 100) // Space for floating buttons
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            
            // Floating action buttons
            floatingActions
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Dynamic title that appears on scroll
                Text(workout.type.rawValue)
                    .font(.headline.weight(.semibold))
                    .opacity(scrollOffset < -50 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset)
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EditWorkoutView(workout: workout)
            }
        }
        .sheet(isPresented: $isEditingCategorySheet) {
            NavigationStack {
                CategoryAndSubcategorySelectionView(
                    selectedCategories: Binding(
                        get: { workout.categories ?? [] },
                        set: { workout.categories = $0 }
                    ),
                    selectedSubcategories: Binding(
                        get: { workout.subcategories ?? [] },
                        set: { workout.subcategories = $0 }
                    ),
                    workoutType: workout.type
                )
            }
        }
        .sheet(isPresented: $showRouteSheet) {
            if workout.type == .running {
                RunningMapAndStatsCard(route: decodedRoute, duration: workout.duration, distance: workout.distance)
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
        VStack(spacing: 24) {
            // Main workout icon and type
            VStack(spacing: 16) {
                ZStack {
                    // Animated gradient background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    workoutTypeColor.opacity(0.2),
                                    workoutTypeColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 16)
                        .scaleEffect(1.1)
                    
                    // Glass circle with icon
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: workoutTypeColor.opacity(0.2), radius: 12, y: 6)
                        .overlay(
                            Image(systemName: WorkoutTypeHelper.iconForType(workout.type))
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(workoutTypeColor)
                                .shadow(color: workoutTypeColor.opacity(0.3), radius: 6, y: 2)
                        )
                }
                
                VStack(spacing: 8) {
                    Text(workout.type.rawValue)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text(DateFormatHelper.friendlyDateTime(workout.startDate))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Key metrics in horizontal scrollable format
            keyMetricsRow
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Key Metrics Row
    private var keyMetricsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Duration (always shown)
                MetricCard(
                    icon: "clock.fill",
                    title: "Duration",
                    value: DurationFormatHelper.formatDuration(workout.duration),
                    color: .blue
                )
                
                // Calories (if available)
                if let calories = workout.calories {
                    MetricCard(
                        icon: "flame.fill",
                        title: "Calories",
                        value: "\(Int(calories))",
                        color: .orange
                    )
                }
                
                // Distance (if available)
                if let distance = workout.distance {
                    MetricCard(
                        icon: "figure.walk",
                        title: "Distance",
                        value: String(format: "%.1f km", distance / 1000),
                        color: .green
                    )
                }
                
                // Date
                MetricCard(
                    icon: "calendar",
                    title: "Date",
                    value: DateFormatHelper.formattedDate(workout.startDate),
                    color: .purple
                )
            }
            .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 20) {
            // Header with edit button
            HStack {
                Text("Categories & Subcategories")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !(workout.categories?.isEmpty ?? true) || !(workout.subcategories?.isEmpty ?? true) {
                    EditCategoriesButton(action: { isEditingCategorySheet = true })
                }
            }
            
            // Content
            if (workout.categories?.isEmpty ?? true) && (workout.subcategories?.isEmpty ?? true) {
                AddCategoriesButton(action: { isEditingCategorySheet = true })
            } else {
                if let categories = workout.categories, !categories.isEmpty {
                    CategoryChips(categories: categories)
                }
                if let subcategories = workout.subcategories, !subcategories.isEmpty {
                    SubcategoryChips(subcategories: subcategories)
                }
            }
        }
        .padding(24)
    }
    
    // MARK: - Floating Actions
    private var floatingActions: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                // Edit button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isEditing = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            workoutTypeColor,
                                            workoutTypeColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: workoutTypeColor.opacity(0.4), radius: 12, y: 6)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
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

private struct EditCategoriesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(ScaleButtonStyle())
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

private struct CategoryChips: View {
    let categories: [WorkoutCategory]
    
    var body: some View {
        VStack(spacing: 24) {
            ForEach(categories) { category in
                CategoryChip(category: category)
            }
        }
    }
    
    private func CategoryChip(category: WorkoutCategory) -> some View {
        Text(category.name)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(chipBackground)
            .foregroundStyle(.primary)
    }
    
    private var chipBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(.primary.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct SubcategoryChips: View {
    let subcategories: [WorkoutSubcategory]
    
    var body: some View {
        VStack(spacing: 24) {
            ForEach(subcategories) { subcategory in
                SubcategoryChip(subcategory: subcategory)
            }
        }
    }
    
    private func SubcategoryChip(subcategory: WorkoutSubcategory) -> some View {
        Text(subcategory.name)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(chipBackground)
            .foregroundStyle(.primary)
    }
    
    private var chipBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(.primary.opacity(0.2), lineWidth: 1)
            )
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
    let workout = Workout(type: .strength, duration: 3600)
    
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
