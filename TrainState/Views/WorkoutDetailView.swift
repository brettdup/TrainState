import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var workout: Workout
    @State private var showingCategoryPicker = false
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    @State private var showingDeleteConfirmation = false

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
                VStack(spacing: 24) {
                    headerCard
                    if workout.duration > 0 || workout.distance ?? 0 > 0 || (workout.calories ?? 0) > 0 {
                        statsCard
                    }
                    categoriesCard
                    if let exercises = workout.exercises, !exercises.isEmpty {
                        exercisesCard(exercises)
                    }
                    if let notes = workout.notes, !notes.isEmpty {
                        notesCard(notes)
                    }
                    editWorkoutButton
                }
                .glassEffectContainer(spacing: 24)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    NavigationLink {
                        EditWorkoutView(workout: workout)
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete Workout", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This workout will be permanently deleted. This action cannot be undone.")
        }
        .sheet(isPresented: $showingCategoryPicker, onDismiss: applyCategorySelection) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategories,
                selectedSubcategories: $selectedSubcategories,
                workoutType: workout.type
            )
        }
        .onAppear {
            selectedCategories = workout.categories ?? []
            selectedSubcategories = workout.subcategories ?? []
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            Image(systemName: workout.type.systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(workout.type.tintColor)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(workout.type.tintColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.system(size: 22, weight: .semibold))
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                if workout.duration > 0 {
                    StatTile(title: "Duration", value: formattedDuration(workout.duration))
                }
                if let distance = workout.distance, distance > 0 {
                    StatTile(title: "Distance", value: String(format: "%.1f km", distance))
                }
                if let calories = workout.calories, calories > 0 {
                    StatTile(title: "Calories", value: "\(Int(calories)) kcal")
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                showingCategoryPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(workout.type.tintColor)
                    Text(categoriesSummary)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private func notesCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    @ViewBuilder
    private var editWorkoutButton: some View {
        if #available(iOS 26, *) {
            NavigationLink {
                EditWorkoutView(workout: workout)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                    Text("Edit Workout")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.glassProminent)
        } else {
            NavigationLink {
                EditWorkoutView(workout: workout)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                    Text("Edit Workout")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private func exercisesCard(_ exercises: [WorkoutExercise]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(exercises.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { exercise in
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise.name)
                            .font(.body.weight(.semibold))
                        Spacer()
                        Text(exerciseStatLine(for: exercise))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let subcategory = exercise.subcategory {
                        Text("Linked: \(subcategory.name)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private func exerciseStatLine(for exercise: WorkoutExercise) -> String {
        var parts: [String] = []
        if let sets = exercise.sets, sets > 0 {
            parts.append("\(sets) sets")
        }
        if let reps = exercise.reps, reps > 0 {
            parts.append("\(reps) reps")
        }
        if let weight = exercise.weight, weight > 0 {
            parts.append(String(format: "%.1f kg", weight))
        }
        return parts.isEmpty ? "Logged" : parts.joined(separator: " • ")
    }

    private var categoriesSummary: String {
        let catNames = selectedCategories.map(\.name)
        let subNames = selectedSubcategories.map(\.name)
        let parts = catNames + subNames
        return parts.isEmpty ? "Select Categories" : parts.joined(separator: ", ")
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }

    private func applyCategorySelection() {
        workout.categories = selectedCategories
        workout.subcategories = selectedSubcategories
        try? modelContext.save()
    }

    private func deleteWorkout() {
        modelContext.delete(workout)
        try? modelContext.save()
        dismiss()
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, configurations: config)
    let context = container.mainContext

    let endurance = WorkoutCategory(name: "Endurance", color: "#FFEAA7", workoutType: .running)
    context.insert(endurance)
    let tempo = WorkoutSubcategory(name: "Tempo", category: endurance)
    context.insert(tempo)

    let workout = Workout(type: .running, startDate: .now, duration: 2700, distance: 5.2, categories: [endurance], subcategories: [tempo])
    context.insert(workout)

    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
