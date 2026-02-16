import SwiftUI
import SwiftData
import CoreLocation

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var workout: Workout
    @Query(sort: \StrengthWorkoutTemplate.updatedAt, order: .reverse) private var strengthTemplates: [StrengthWorkoutTemplate]
    @State private var showingCategoryPicker = false
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    @State private var showingDeleteConfirmation = false
    @State private var showingRouteMapSheet = false
    @State private var showingSaveTemplateAlert = false
    @State private var templateName = ""

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
                    if workout.duration > 0 || workout.distance ?? 0 > 0 || (workout.calories ?? 0) > 0 || (workout.rating ?? 0) > 0 {
                        statsCard
                    }
                    categoriesCard
                    if let exercises = workout.exercises, !exercises.isEmpty {
                        exercisesCard(exercises)
                    }
                    if let notes = workout.notes, !notes.isEmpty {
                        notesCard(notes)
                    }
                    if let route = workout.route?.decodedRoute, !route.isEmpty {
                        routeCard(route)
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

                    if canSaveAsStrengthTemplate {
                        Button {
                            templateName = defaultTemplateName
                            showingSaveTemplateAlert = true
                        } label: {
                            Label("Save as Template", systemImage: "square.and.arrow.down")
                        }
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
        .alert("Save as Template", isPresented: $showingSaveTemplateAlert) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {
                templateName = ""
            }
            Button("Save") {
                saveWorkoutAsTemplate()
                templateName = ""
            }
            .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Save this workout's exercises as a reusable strength template.")
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
        .sheet(isPresented: $showingRouteMapSheet) {
            if let route = workout.route?.decodedRoute, !route.isEmpty {
                RouteMapSheetView(route: route)
            } else {
                EmptyView()
            }
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
        .glassCard()
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
                if let rating = workout.rating, rating > 0 {
                    StatTile(title: "Rating", value: String(format: "%.1f/10", rating))
                }
            }
        }
        .padding(20)
        .glassCard()
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
        .glassCard()
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
        .glassCard()
    }

    private func routeCard(_ route: [CLLocation]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Route")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            RouteMapView(route: route)
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture {
                    showingRouteMapSheet = true
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
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
            HStack {
                Text("Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 10) {
                ForEach(exercises.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { exercise in
                    NavigationLink {
                        ExerciseInsightsView(
                            exerciseName: exercise.name,
                            subcategoryID: exercise.subcategory?.id
                        )
                    } label: {
                        ExerciseCardView(
                            exercise: exercise,
                            showChevron: true,
                            colorScheme: colorScheme
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
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

    private var canSaveAsStrengthTemplate: Bool {
        workout.type == .strength && !(workout.exercises?.isEmpty ?? true)
    }

    private var defaultTemplateName: String {
        let base = "Strength \(workout.startDate.formatted(date: .abbreviated, time: .omitted))"
        let existingNames = Set(strengthTemplates.map { $0.name.lowercased() })
        if !existingNames.contains(base.lowercased()) {
            return base
        }
        var suffix = 2
        while existingNames.contains("\(base) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    private func saveWorkoutAsTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let sortedWorkoutExercises = (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let templateExercises = sortedWorkoutExercises.enumerated().map { index, exercise in
            StrengthWorkoutTemplateExercise(
                name: exercise.name,
                orderIndex: index,
                sets: exercise.sets,
                reps: exercise.reps,
                weight: exercise.weight,
                subcategoryID: exercise.subcategory?.id
            )
        }
        guard !templateExercises.isEmpty else { return }

        if let existing = strengthTemplates.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            existing.name = name
            existing.mainCategoryRawValue = workout.type.rawValue
            existing.updatedAt = Date()
            existing.exercises = templateExercises
        } else {
            let template = StrengthWorkoutTemplate(name: name, mainCategoryRawValue: workout.type.rawValue, exercises: templateExercises)
            modelContext.insert(template)
        }
        try? modelContext.save()
    }
}

private struct RouteMapSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let route: [CLLocation]

    var body: some View {
        NavigationStack {
            RouteMapView(route: route)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Workout Route")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
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
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self, configurations: config)
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
