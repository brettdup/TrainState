import SwiftUI
import SwiftData
import RevenueCatUI
import HealthKit

struct CategoriesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutCategory.name) private var categories: [WorkoutCategory]
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var expandedCategoryId: UUID?
    @State private var selectedSubcategory: WorkoutSubcategory?
    @State private var showingAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var subcategoryParentCategory: WorkoutCategory?
    @State private var showingAddExerciseTemplate = false
    @State private var newExerciseTemplateName = ""
    @State private var templateParentSubcategory: WorkoutSubcategory?
    @State private var showingPaywall = false
    @State private var categoryPendingDelete: WorkoutCategory?
    @State private var subcategoryPendingDelete: WorkoutSubcategory?

    private var groupedCategories: [(id: String, title: String, categories: [WorkoutCategory])] {
        let grouped = Dictionary(grouping: categories) { category in
            category.appleWorkoutActivityType?.rawValue
        }

        var sections = grouped.map { rawValue, items in
            let title: String
            if let rawValue,
               let activityType = HKWorkoutActivityType(rawValue: UInt(rawValue)) {
                title = activityType.displayName
            } else {
                title = items.first?.activityDisplayName ?? "Unspecified"
            }

            return (
                id: rawValue.map { String($0) } ?? "unspecified",
                title: title,
                categories: items.sorted { $0.name < $1.name }
            )
        }

        sections.sort { lhs, rhs in
            if lhs.title == "Unspecified" { return false }
            if rhs.title == "Unspecified" { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return sections
    }

    private func canAddSubcategory(to category: WorkoutCategory) -> Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || subcategoriesFor(category).count < PremiumLimits.freeSubcategoryPerCategoryLimit
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Categories", value: "\(categories.count)")
                LabeledContent("Subcategories", value: "\(subcategories.count)")
                LabeledContent("Exercises", value: "\(exerciseTemplates.count)")
            } footer: {
                Text("Expand a category to manage its subcategories, then expand a subcategory to manage its exercise library.")
            }

            if groupedCategories.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Categories Yet",
                        systemImage: "square.grid.2x2",
                        description: Text("Create a category from the workout flow first, then manage its subcategories and exercises here.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(groupedCategories, id: \.id) { section in
                    Section(section.title) {
                        ForEach(section.categories) { category in
                            categoryDisclosure(for: category)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Categories")
        .sheet(isPresented: $showingAddSubcategory) {
            addSubcategorySheet
        }
        .sheet(isPresented: $showingAddExerciseTemplate) {
            addExerciseTemplateSheet
        }
        .sheet(item: $selectedSubcategory) { subcategory in
            subcategorySheet(for: subcategory)
        }
        .sheet(isPresented: $showingPaywall) {
            if let offering = purchaseManager.offerings?.current {
                PaywallView(offering: offering)
            } else {
                PaywallPlaceholderView(onDismiss: { showingPaywall = false })
            }
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: categoryDeleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: categoryPendingDelete
        ) { category in
            Button("Delete Category", role: .destructive) {
                deleteCategory(category)
            }
            Button("Cancel", role: .cancel) {
                categoryPendingDelete = nil
            }
        } message: { category in
            Text(categoryDeleteMessage(for: category))
        }
        .confirmationDialog(
            "Delete Subcategory",
            isPresented: subcategoryDeleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: subcategoryPendingDelete
        ) { subcategory in
            Button("Delete Subcategory", role: .destructive) {
                deleteSubcategory(subcategory)
            }
            Button("Cancel", role: .cancel) {
                subcategoryPendingDelete = nil
            }
        } message: { subcategory in
            Text(subcategoryDeleteMessage(for: subcategory))
        }
    }

    private func subcategoriesFor(_ category: WorkoutCategory) -> [WorkoutSubcategory] {
        subcategories.filter { $0.category?.id == category.id }
    }

    private func exerciseTemplatesFor(_ subcategory: WorkoutSubcategory) -> [SubcategoryExercise] {
        exerciseTemplates
            .filter { $0.subcategory?.id == subcategory.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var categoryDeleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { categoryPendingDelete != nil },
            set: { if !$0 { categoryPendingDelete = nil } }
        )
    }

    private var subcategoryDeleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { subcategoryPendingDelete != nil },
            set: { if !$0 { subcategoryPendingDelete = nil } }
        )
    }

    private func categoryDisclosure(for category: WorkoutCategory) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCategoryId == category.id },
                set: { expandedCategoryId = $0 ? category.id : nil }
            )
        ) {
            let categorySubcategories = subcategoriesFor(category)

            if categorySubcategories.isEmpty {
                ContentUnavailableView(
                    "No Subcategories",
                    systemImage: "tag",
                    description: Text("Add a subcategory to start organizing exercises under \(category.name).")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(categorySubcategories) { subcategory in
                    Button {
                        selectedSubcategory = subcategory
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tag.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(subcategory.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(exerciseTemplatesFor(subcategory).count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            subcategoryPendingDelete = subcategory
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                if canAddSubcategory(to: category) {
                    subcategoryParentCategory = category
                    newSubcategoryName = ""
                    showingAddSubcategory = true
                } else {
                    Task {
                        await purchaseManager.loadProducts()
                        await purchaseManager.updatePurchasedProducts()
                        showingPaywall = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Label("Add Subcategory", systemImage: "plus.circle")
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, categorySubcategories.isEmpty ? 8 : 4)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: category.color) ?? .gray)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.headline)
                    Text("\(subcategoriesFor(category).count) subcategories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                categoryPendingDelete = category
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func subcategorySheet(for subcategory: WorkoutSubcategory) -> some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Parent Category", value: subcategory.category?.name ?? "Unlinked")
                    LabeledContent("Exercises", value: "\(exerciseTemplatesFor(subcategory).count)")
                }

                Section("Exercises") {
                    let templates = exerciseTemplatesFor(subcategory)

                    if templates.isEmpty {
                        ContentUnavailableView(
                            "No Exercises",
                            systemImage: "dumbbell",
                            description: Text("Add an exercise template to build out \(subcategory.name).")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(templates) { template in
                            HStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)

                                Text(template.name)
                                    .font(.subheadline)

                                Spacer()

                                Button(role: .destructive) {
                                    modelContext.delete(template)
                                    try? modelContext.save()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button {
                        templateParentSubcategory = subcategory
                        newExerciseTemplateName = ""
                        showingAddExerciseTemplate = true
                    } label: {
                        HStack(spacing: 8) {
                            Label("Add Exercise", systemImage: "plus.circle")
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(subcategory.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        selectedSubcategory = nil
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        subcategoryPendingDelete = subcategory
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private func categoryDeleteMessage(for category: WorkoutCategory) -> String {
        let linkedSubcategories = subcategoriesFor(category).count
        let linkedTemplates = subcategoriesFor(category).reduce(0) { $0 + exerciseTemplatesFor($1).count }
        let linkedWorkouts = category.workouts?.count ?? 0

        return "\(category.name) will be permanently deleted. This will also delete \(linkedSubcategories) subcategories and \(linkedTemplates) exercise templates. \(linkedWorkouts == 0 ? "No workouts are currently linked." : "\(linkedWorkouts) linked workouts will remain, but this category and its subcategory links will be removed from them.")"
    }

    private func subcategoryDeleteMessage(for subcategory: WorkoutSubcategory) -> String {
        let linkedTemplates = exerciseTemplatesFor(subcategory).count
        let linkedWorkouts = subcategory.workouts?.count ?? 0
        let linkedLoggedExercises = subcategory.exercises?.count ?? 0

        return "\(subcategory.name) will be permanently deleted. This will also delete \(linkedTemplates) exercise templates. \(linkedWorkouts == 0 && linkedLoggedExercises == 0 ? "No workouts or logged exercises are currently linked." : "\(linkedWorkouts) linked workouts and \(linkedLoggedExercises) logged exercises will remain, but their subcategory link will be removed.")"
    }

    private func deleteCategory(_ category: WorkoutCategory) {
        if expandedCategoryId == category.id {
            expandedCategoryId = nil
        }
        if subcategoryParentCategory?.id == category.id {
            subcategoryParentCategory = nil
        }
        modelContext.delete(category)
        try? modelContext.save()
        categoryPendingDelete = nil
    }

    private func deleteSubcategory(_ subcategory: WorkoutSubcategory) {
        if selectedSubcategory?.id == subcategory.id {
            selectedSubcategory = nil
        }
        if templateParentSubcategory?.id == subcategory.id {
            templateParentSubcategory = nil
            showingAddExerciseTemplate = false
            newExerciseTemplateName = ""
        }
        modelContext.delete(subcategory)
        try? modelContext.save()
        subcategoryPendingDelete = nil
    }

    private var addSubcategorySheet: some View {
        NavigationStack {
            Form {
                Section("Subcategory") {
                    TextField("Subcategory name", text: $newSubcategoryName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                if let cat = subcategoryParentCategory {
                    Section("Parent Category") {
                        Text(cat.name)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSubcategory = false
                        subcategoryParentCategory = nil
                        newSubcategoryName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSubcategory()
                    }
                    .disabled(newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var addExerciseTemplateSheet: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $newExerciseTemplateName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                if let subcategory = templateParentSubcategory {
                    Section("Parent Subcategory") {
                        Text(subcategory.name)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddExerciseTemplate = false
                        templateParentSubcategory = nil
                        newExerciseTemplateName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addExerciseTemplate()
                    }
                    .disabled(newExerciseTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addSubcategory() {
        let name = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let category = subcategoryParentCategory else { return }
        let sub = WorkoutSubcategory(name: name, category: category)
        modelContext.insert(sub)
        try? modelContext.save()
        DataInitializationManager.shared.initializeDefaultExerciseTemplatesIfNeeded(context: modelContext)
        newSubcategoryName = ""
        showingAddSubcategory = false
        subcategoryParentCategory = nil
    }

    private func addExerciseTemplate() {
        let name = newExerciseTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let subcategory = templateParentSubcategory else { return }
        let order = exerciseTemplatesFor(subcategory).count
        let template = SubcategoryExercise(name: name, subcategory: subcategory, orderIndex: order)
        modelContext.insert(template)
        try? modelContext.save()
        newExerciseTemplateName = ""
        templateParentSubcategory = nil
        showingAddExerciseTemplate = false
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, SubcategoryExercise.self, configurations: config)
    let context = container.mainContext

    let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
    let legs = WorkoutCategory(name: "Legs", color: "#45B7D1", workoutType: .strength)
    context.insert(push)
    context.insert(legs)

    let benchPress = WorkoutSubcategory(name: "Bench Press", category: push)
    context.insert(benchPress)
    let squat = WorkoutSubcategory(name: "Squat", category: legs)
    context.insert(squat)
    context.insert(SubcategoryExercise(name: "Barbell Bench Press", subcategory: benchPress))
    context.insert(SubcategoryExercise(name: "Incline Dumbbell Press", subcategory: benchPress))

    return NavigationStack {
        CategoriesManagementView()
    }
    .modelContainer(container)
}
