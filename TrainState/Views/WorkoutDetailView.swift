import SwiftUI
import SwiftData
import MapKit

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingCategorySelection = false

    private var exercises: [WorkoutExercise] { (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex } }

    // MARK: - Theming
    private var accentColor: Color {
        switch workout.type {
        case .strength: return .purple
        case .cardio:   return .red
        case .yoga:     return .mint
        case .running:  return .blue
        case .cycling:  return .green
        case .swimming: return .cyan
        case .other:    return .gray
        }
    }

    private var iconName: String {
        WorkoutTypeHelper.iconForType(workout.type)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    if #available(iOS 26.0, *) {
                        GlassEffectContainer(spacing: 8) {
                            VStack(spacing: 16) {
                                headerView

                                metricsGrid

                                categoriesCard

                                if !exercises.isEmpty {
                                    exercisesCard
                                }

                                if let notes = workout.notes, !notes.isEmpty {
                                    notesCard(text: notes)
                                }

                                if let route = workout.route?.decodedRoute, !route.isEmpty {
                                    routeCard(route: route)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    } else {
                        VStack(spacing: 16) {
                            headerView

                            metricsGrid

                            categoriesCard

                            if !exercises.isEmpty {
                                exercisesCard
                            }

                            if let notes = workout.notes, !notes.isEmpty {
                                notesCard(text: notes)
                            }

                            if let route = workout.route?.decodedRoute, !route.isEmpty {
                                routeCard(route: route)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(workout.type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        let label = Text("Done")
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        label
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionSheet(workout: workout)
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private var headerView: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.type.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(DateFormatHelper.friendlyDateTime(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let hkName = workout.hkActivityTypeName {
                Text(hkName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
            }
        }
        .padding(20)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }

    // MARK: - Metrics
    private var metricsGrid: some View {
        VStack(spacing: 12) {
            // Date (full-width row)
            MetricCard(icon: "calendar", title: "Date", value: DateFormatHelper.formattedDate(workout.startDate), tint: .blue)

            // Remaining metrics in a two-column grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                // Duration
                if workout.duration > 0 {
                    MetricCard(icon: "clock", title: "Duration", value: DurationFormatHelper.formatDuration(workout.duration), tint: .indigo)
                }

                // Distance
                if let distance = workout.distance {
                    let formatted: String = {
                        switch workout.type {
                        case .swimming:
                            return String(format: "%.0f m", distance)
                        default:
                            return String(format: "%.1f km", distance / 1000)
                        }
                    }()
                    MetricCard(icon: "figure.walk", title: "Distance", value: formatted, tint: .teal)
                }

                // Calories
                if let calories = workout.calories {
                    MetricCard(icon: "flame.fill", title: "Calories", value: "\(Int(calories)) kcal", tint: .orange)
                }
            }
        }
    }

    // MARK: - Categories
    @ViewBuilder
    private var categoriesCard: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Categories")
                    .font(.headline)
                Spacer()
                Button {
                    showingCategorySelection = true
                } label: {
                    let label = Label("Edit", systemImage: "tag")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    label
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if let categories = workout.categories, !categories.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(categories, id: \.id) { category in
                        CategoryChip(category: category)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                    Text("No categories yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.subheadline)
            }
        }
        .padding(20)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }

    // MARK: - Exercises
    @ViewBuilder
    private var exercisesCard: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(exercises, id: \.id) { exercise in
                    ExerciseCard(exercise: exercise, accent: accentColor)
                }
            }
        }
        .padding(20)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }

    // MARK: - Notes
    @ViewBuilder
    private func notesCard(text: String) -> some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(20)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }

    // MARK: - Route
    @ViewBuilder
    private func routeCard(route: [CLLocation]) -> some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)
            RunningMapAndStatsCard(
                route: route,
                duration: workout.duration,
                distance: workout.distance
            )
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Components
private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        let content = HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(20)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct ExerciseCard: View {
    let exercise: WorkoutExercise
    let accent: Color

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                Spacer()
            }

            HStack(spacing: 8) {
                if let sets = exercise.sets {
                    InfoPill(text: "\(sets) sets")
                }
                if let reps = exercise.reps {
                    InfoPill(text: "\(reps) reps")
                }
                if let weight = exercise.weight {
                    InfoPill(text: String(format: "%.1f kg", weight))
                }
            }

            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct InfoPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(.systemGray5))
            )
    }
}
