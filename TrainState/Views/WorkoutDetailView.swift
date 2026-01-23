import SwiftUI
import SwiftData
import MapKit

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingCategorySelection = false

    private var exercises: [WorkoutExercise] { (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex } }

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                categoriesSection
                if !exercises.isEmpty {
                    exercisesSection
                }
                if let notes = workout.notes, !notes.isEmpty {
                    notesSection
                }
                if let route = workout.route?.decodedRoute, !route.isEmpty {
                    routeSection(route: route)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(workout.type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionSheet(workout: workout)
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section("Overview") {
            HStack(spacing: 12) {
                Image(systemName: WorkoutTypeHelper.iconForType(workout.type))
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.type.rawValue)
                        .font(.headline)
                    if let hkName = workout.hkActivityTypeName {
                        Text(hkName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(DateFormatHelper.friendlyDateTime(workout.startDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            overviewRow(
                label: "Date",
                systemImage: "calendar",
                value: DateFormatHelper.formattedDate(workout.startDate)
            )

            if workout.duration > 0 {
                overviewRow(
                    label: "Duration",
                    systemImage: "clock.fill",
                    value: DurationFormatHelper.formatDuration(workout.duration)
                )
            }

            if let distance = workout.distance {
                overviewRow(
                    label: "Distance",
                    systemImage: "figure.walk",
                    value: String(format: "%.1f km", distance / 1000)
                )
            }

            if let calories = workout.calories {
                overviewRow(
                    label: "Calories",
                    systemImage: "flame.fill",
                    value: "\(Int(calories)) kcal"
                )
            }
        }
    }

    private var categoriesSection: some View {
        Section("Categories") {
            if let categories = workout.categories, !categories.isEmpty {
                ForEach(categories, id: \.id) { category in
                    HStack {
                        Text(category.name)
                        Spacer()
                        if let color = Color(hex: category.color) {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            } else {
                Text("No categories")
                    .foregroundStyle(.secondary)
            }

            Button {
                showingCategorySelection = true
            } label: {
                Label("Edit Categories", systemImage: "tag")
            }
        }
    }

    private var exercisesSection: some View {
        Section("Exercises") {
            ForEach(exercises, id: \.id) { exercise in
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))

                    HStack(spacing: 12) {
                        if let sets = exercise.sets {
                            Text("\(sets) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let reps = exercise.reps {
                            Text("\(reps) reps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let weight = exercise.weight {
                            Text(String(format: "%.1f kg", weight))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            if let notes = workout.notes {
                Text(notes)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func routeSection(route: [CLLocation]) -> some View {
        Section("Route") {
            RunningMapAndStatsCard(
                route: route,
                duration: workout.duration,
                distance: workout.distance
            )
            .listRowInsets(EdgeInsets())
        }
    }

    private func overviewRow(label: String, systemImage: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    private var durationFormatter: DateComponentsFormatter {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }

    private var distanceFormatter: MeasurementFormatter {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, WorkoutRoute.self, configurations: config)
    let sample = Workout(type: .running, startDate: Date(), duration: 1800, distance: 5000)
    return WorkoutDetailView(workout: sample)
        .modelContainer(container)
}
