import SwiftData
import SwiftUI

struct StrengthTemplatesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StrengthWorkoutTemplate.updatedAt, order: .reverse) private var templates: [StrengthWorkoutTemplate]
    @State private var showingCreateAlert = false
    @State private var newTemplateName = ""

    var body: some View {
        List {
            if templates.isEmpty {
                Text("No strength templates yet. Save one from a workout or create one here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(templates) { template in
                    NavigationLink {
                        StrengthTemplateEditorView(template: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.body.weight(.semibold))
                            Text(templateSubtitle(template))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
        }
        .navigationTitle("Strength Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newTemplateName = "New Template"
                    showingCreateAlert = true
                } label: {
                    Label("New Template", systemImage: "plus")
                }
            }
        }
        .alert("New Template", isPresented: $showingCreateAlert) {
            TextField("Template name", text: $newTemplateName)
            Button("Cancel", role: .cancel) {
                newTemplateName = ""
            }
            Button("Create") {
                createTemplate()
                newTemplateName = ""
            }
            .disabled(newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Create an empty template, then add exercises.")
        }
    }

    private func templateSubtitle(_ template: StrengthWorkoutTemplate) -> String {
        let count = template.exercises?.count ?? 0
        let updated = template.updatedAt.formatted(date: .abbreviated, time: .omitted)
        let categoryName = template.mainCategoryRawValue
        return "\(categoryName) • \(count) exercise\(count == 1 ? "" : "s") • Updated \(updated)"
    }

    private func createTemplate() {
        let trimmed = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let template = StrengthWorkoutTemplate(name: trimmed, mainCategoryRawValue: WorkoutType.strength.rawValue)
        modelContext.insert(template)
        try? modelContext.save()
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
    }
}

private struct StrengthTemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseOptions: [SubcategoryExercise]
    @Bindable var template: StrengthWorkoutTemplate
    @State private var exerciseEntries: [ExerciseLogEntry] = []
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var hasLoadedTemplate = false

    private var availableOptions: [ExerciseQuickAddOption] {
        let allowedSubcategoryIDs = Set(availableSubcategories.map(\.id))
        return exerciseOptions.compactMap { option -> ExerciseQuickAddOption? in
            guard let subcategoryID = option.subcategory?.id else { return nil }
            guard allowedSubcategoryIDs.contains(subcategoryID) else { return nil }
            return ExerciseQuickAddOption(name: option.name, subcategoryID: subcategoryID)
        }
    }
    private var availableSubcategories: [WorkoutSubcategory] {
        let type = WorkoutType(rawValue: template.mainCategoryRawValue) ?? .strength
        return subcategories.filter { $0.category?.workoutType == type }
    }

    var body: some View {
        List {
            templateSection
            exercisesSection
        }
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeExerciseSelection) { selection in
            if let index = exerciseEntries.firstIndex(where: { $0.id == selection.id }) {
                ExerciseEditorSheetView(
                    entry: $exerciseEntries[index],
                    availableSubcategories: availableSubcategories,
                    availableOptions: availableOptions,
                    onDelete: {
                        exerciseEntries.removeAll { $0.id == selection.id }
                        persistTemplateExercises()
                    },
                    mode: .template
                )
            } else {
                EmptyView()
            }
        }
        .onAppear {
            guard !hasLoadedTemplate else { return }
            hasLoadedTemplate = true
            loadTemplateEntries()
        }
        .onChange(of: activeExerciseSelection) { _, newValue in
            if newValue == nil {
                // Defer cleanup so we don't mutate the entries array while the
                // sheet is still using an index-based binding, which can crash.
                DispatchQueue.main.async {
                    exerciseEntries.removeAll { $0.isEmpty }
                    persistTemplateExercises()
                }
            }
        }
        .onChange(of: exerciseEntries) { _, _ in
            persistTemplateExercises()
        }
        .onDisappear {
            persistTemplateExercises()
            try? modelContext.save()
        }
    }

    private var templateSection: some View {
        Section("Template") {
            TextField("Template name", text: $template.name)
                .onChange(of: template.name) { _, _ in
                    saveTemplateName()
                }

            Text("Main Category: \(template.mainCategoryRawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var exercisesSection: some View {
        Section("Exercises") {
            if exerciseEntries.isEmpty {
                Text("No exercises yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exerciseEntries) { entry in
                    Button {
                        activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.trimmedName.isEmpty ? "Unnamed exercise" : entry.trimmedName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)

                                if let summary = exerciseSummary(for: entry) {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                addAndEditNewExercise()
            } label: {
                Label("Add Exercise", systemImage: "plus.circle")
            }
        }
    }

    private func loadTemplateEntries() {
        let sortedExercises = (template.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        exerciseEntries = sortedExercises.map { item in
            let decodedPlan = item.decodedSetPlan()
            let plannedSetEntries: [ExerciseSetEntry] = decodedPlan.map {
                ExerciseSetEntry(reps: max($0.reps, 0), weight: max($0.weight, 0), isCompleted: false)
            }
            return ExerciseLogEntry(
                name: item.name,
                sets: item.sets,
                reps: item.reps,
                weight: item.weight,
                subcategoryID: item.subcategoryID,
                setEntries: plannedSetEntries
            )
        }
    }

    private func addAndEditNewExercise() {
        let newEntry = ExerciseLogEntry(subcategoryID: availableSubcategories.first?.id)
        exerciseEntries.append(newEntry)
        activeExerciseSelection = ExerciseEditorSelection(id: newEntry.id)
    }

    private func persistTemplateExercises() {
        let previousExercises = template.exercises ?? []
        for existing in previousExercises {
            modelContext.delete(existing)
        }

        let mapped = exerciseEntries
            .enumerated()
            .compactMap { index, entry -> StrengthWorkoutTemplateExercise? in
                let name = entry.trimmedName
                guard !name.isEmpty else { return nil }
                return StrengthWorkoutTemplateExercise(
                    name: name,
                    orderIndex: index,
                    sets: entry.sets,
                    reps: entry.reps,
                    weight: entry.weight,
                    subcategoryID: entry.subcategoryID,
                    setPlanJSON: StrengthWorkoutTemplateExercise.encodeSetPlan(
                        entry.setEntries.map { setEntry in
                            TemplateSetPlanEntry(reps: max(setEntry.reps, 0), weight: max(setEntry.weight, 0))
                        }
                    )
                )
            }

        template.exercises = mapped
        template.updatedAt = Date()
        try? modelContext.save()
    }

    private func saveTemplateName() {
        template.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        template.updatedAt = Date()
        try? modelContext.save()
    }

    private func exerciseSummary(for entry: ExerciseLogEntry) -> String? {
        let setsText = entry.effectiveSetCount.map { "\($0)x" }
        let repsText = entry.effectiveReps.map { "\($0)" }
        let weightText: String? = {
            guard let w = entry.effectiveWeight, w > 0 else { return nil }
            return "\(ExerciseLogEntry.displayWeight(w)) kg"
        }()
        let primary = [setsText, repsText].compactMap { $0 }.joined(separator: " ")

        if let weightText {
            return primary.isEmpty ? weightText : "\(primary) · \(weightText)"
        }
        return primary.isEmpty ? nil : primary
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: StrengthWorkoutTemplate.self,
        StrengthWorkoutTemplateExercise.self,
        WorkoutCategory.self,
        WorkoutSubcategory.self,
        SubcategoryExercise.self,
        configurations: config
    )
    let context = container.mainContext

    let category = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
    context.insert(category)
    let chest = WorkoutSubcategory(name: "Chest", category: category)
    context.insert(chest)

    let template = StrengthWorkoutTemplate(name: "Push Day")
    template.exercises = [
        StrengthWorkoutTemplateExercise(name: "Bench Press", orderIndex: 0, sets: 4, reps: 6, weight: 80, subcategoryID: chest.id),
        StrengthWorkoutTemplateExercise(name: "Incline Press", orderIndex: 1, sets: 3, reps: 10, weight: 30, subcategoryID: chest.id)
    ]
    context.insert(template)

    return NavigationStack {
        StrengthTemplatesManagementView()
    }
    .modelContainer(container)
}
