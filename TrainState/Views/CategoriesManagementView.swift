import SwiftUI
import SwiftData
import HealthKit

struct CategoriesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutCategory.name) private var categories: [WorkoutCategory]
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var expandedCategoryId: UUID?
    @State private var selectedSubcategory: WorkoutSubcategory?
    @State private var selectedExerciseTemplate: SubcategoryExercise?
    @State private var subcategoryPendingMove: WorkoutSubcategory?
    @State private var showingAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var subcategoryParentCategory: WorkoutCategory?
    @State private var showingAddExerciseTemplate = false
    @State private var newExerciseTemplateName = ""
    @State private var templateParentSubcategory: WorkoutSubcategory?
    @State private var showingCategoryTools = false
    @State private var showingPaywall = false
    @State private var categoryPendingDelete: WorkoutCategory?
    @State private var subcategoryPendingDelete: WorkoutSubcategory?
    @State private var exerciseTemplatePendingDelete: SubcategoryExercise?
    @State private var exerciseSearchText = ""
    @State private var expandedLibraryCategoryIDs: Set<String> = []
    @State private var expandedLibrarySubcategoryIDs: Set<String> = []

    let workoutType: WorkoutType?
    let appleWorkoutActivityType: HKWorkoutActivityType?

    init(
        workoutType: WorkoutType? = nil,
        appleWorkoutActivityType: HKWorkoutActivityType? = nil
    ) {
        self.workoutType = workoutType
        self.appleWorkoutActivityType = appleWorkoutActivityType
    }

    private var relevantCategories: [WorkoutCategory] {
        guard let workoutType else { return categories }
        return categories.filter {
            $0.matches(
                appleWorkoutActivityType: appleWorkoutActivityType,
                fallbackWorkoutType: workoutType
            )
        }
    }

    private var relevantSubcategories: [WorkoutSubcategory] {
        let categoryIDs = Set(relevantCategories.map(\.id))
        return subcategories.filter { subcategory in
            guard let category = subcategory.category else { return false }
            return categoryIDs.contains(category.id)
        }
    }

    private var relevantExerciseTemplates: [SubcategoryExercise] {
        let subcategoryIDs = Set(relevantSubcategories.map(\.id))
        return exerciseTemplates.filter { template in
            guard let subcategoryID = template.subcategory?.id else { return false }
            return subcategoryIDs.contains(subcategoryID)
        }
    }

    private var groupedCategories: [(id: String, title: String, categories: [WorkoutCategory])] {
        let grouped = Dictionary(grouping: relevantCategories) { category in
            category.resolvedWorkoutType?.rawValue ?? category.activityDisplayName
        }

        var sections = grouped.map { title, items in
            return (
                id: title,
                title: title.isEmpty ? "Unspecified" : title,
                categories: items.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            )
        }

        sections.sort { lhs, rhs in
            if lhs.title == "Unspecified" { return false }
            if rhs.title == "Unspecified" { return true }

            let lhsIndex = WorkoutType.allCases.firstIndex { $0.rawValue == lhs.title }
            let rhsIndex = WorkoutType.allCases.firstIndex { $0.rawValue == rhs.title }
            if let lhsIndex, let rhsIndex {
                return lhsIndex < rhsIndex
            }
            if lhsIndex != nil { return true }
            if rhsIndex != nil { return false }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return sections
    }

    private var filteredExerciseTemplates: [SubcategoryExercise] {
        let search = exerciseSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return relevantExerciseTemplates
            .filter { template in
                guard !search.isEmpty else { return true }
                return template.name.localizedCaseInsensitiveContains(search) ||
                    (template.subcategory?.name.localizedCaseInsensitiveContains(search) ?? false) ||
                    (template.subcategory?.category?.name.localizedCaseInsensitiveContains(search) ?? false)
            }
            .sorted {
                let lhsName = $0.name.localizedCaseInsensitiveCompare($1.name)
                if lhsName == .orderedSame {
                    return ($0.subcategory?.name ?? "").localizedCaseInsensitiveCompare($1.subcategory?.name ?? "") == .orderedAscending
                }
                return lhsName == .orderedAscending
            }
    }

    private struct ExerciseLibraryCategoryGroup: Identifiable {
        let category: WorkoutCategory?
        let subcategories: [ExerciseLibrarySubcategoryGroup]

        var id: String {
            category?.id.uuidString ?? "unlinked-category"
        }
    }

    private struct ExerciseLibraryTypeGroup: Identifiable {
        let title: String
        let categories: [ExerciseLibraryCategoryGroup]

        var id: String { title }
    }

    private struct ExerciseLibrarySubcategoryGroup: Identifiable {
        let subcategory: WorkoutSubcategory?
        let templates: [SubcategoryExercise]

        var id: String {
            subcategory?.id.uuidString ?? "unlinked-subcategory"
        }
    }

    private var groupedExerciseLibraryByType: [ExerciseLibraryTypeGroup] {
        let categoryGroups = groupedExerciseLibrary
        let groupedByType = Dictionary(grouping: categoryGroups) { group in
            group.category?.resolvedWorkoutType?.rawValue ?? group.category?.activityDisplayName ?? "Unspecified"
        }

        let typeGroups = groupedByType.map { title, categories in
            ExerciseLibraryTypeGroup(
                title: title.isEmpty ? "Unspecified" : title,
                categories: categories.sorted { lhs, rhs in
                    categorySortTitle(lhs).localizedCaseInsensitiveCompare(categorySortTitle(rhs)) == .orderedAscending
                }
            )
        }

        return typeGroups.sorted { lhs, rhs in
            typeSortTitle(lhs.title, rhs.title)
        }
    }

    private var groupedExerciseLibrary: [ExerciseLibraryCategoryGroup] {
        let groupedByCategory = Dictionary(grouping: filteredExerciseTemplates) { template in
            template.subcategory?.category?.id
        }

        let groups = groupedByCategory.map { categoryID, templates in
            exerciseLibraryCategoryGroup(categoryID: categoryID, templates: templates)
        }

        return groups.sorted { lhs, rhs in
            categorySortTitle(lhs).localizedCaseInsensitiveCompare(categorySortTitle(rhs)) == .orderedAscending
        }
    }

    private func exerciseLibraryCategoryGroup(
        categoryID: UUID?,
        templates: [SubcategoryExercise]
    ) -> ExerciseLibraryCategoryGroup {
        let category = categoryID.flatMap(categoryForID)
        let groupedBySubcategory = Dictionary(grouping: templates) { template in
            template.subcategory?.id
        }

        let subcategoryGroups = groupedBySubcategory
            .map { subcategoryID, templates in
                exerciseLibrarySubcategoryGroup(subcategoryID: subcategoryID, templates: templates)
            }
            .sorted { lhs, rhs in
                subcategorySortTitle(lhs).localizedCaseInsensitiveCompare(subcategorySortTitle(rhs)) == .orderedAscending
            }

        return ExerciseLibraryCategoryGroup(category: category, subcategories: subcategoryGroups)
    }

    private func exerciseLibrarySubcategoryGroup(
        subcategoryID: UUID?,
        templates: [SubcategoryExercise]
    ) -> ExerciseLibrarySubcategoryGroup {
        let subcategory = subcategoryID.flatMap(subcategoryForID)
        let sortedTemplates = templates.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return ExerciseLibrarySubcategoryGroup(subcategory: subcategory, templates: sortedTemplates)
    }

    private func categoryForID(_ id: UUID) -> WorkoutCategory? {
        relevantCategories.first { $0.id == id }
    }

    private func subcategoryForID(_ id: UUID) -> WorkoutSubcategory? {
        relevantSubcategories.first { $0.id == id }
    }

    private func categorySortTitle(_ group: ExerciseLibraryCategoryGroup) -> String {
        group.category?.name ?? "Unlinked"
    }

    private func subcategorySortTitle(_ group: ExerciseLibrarySubcategoryGroup) -> String {
        group.subcategory?.name ?? "Unlinked"
    }

    private func typeSortTitle(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "Unspecified" { return false }
        if rhs == "Unspecified" { return true }
        let lhsIndex = WorkoutType.allCases.firstIndex { $0.rawValue == lhs }
        let rhsIndex = WorkoutType.allCases.firstIndex { $0.rawValue == rhs }
        if let lhsIndex, let rhsIndex {
            return lhsIndex < rhsIndex
        }
        if lhsIndex != nil { return true }
        if rhsIndex != nil { return false }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private func canAddSubcategory(to category: WorkoutCategory) -> Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || subcategoriesFor(category).count < PremiumLimits.freeSubcategoryPerCategoryLimit
    }

    var body: some View {
        List {
            if relevantExerciseTemplates.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Exercises Yet",
                        systemImage: "dumbbell",
                        description: Text(workoutType == nil ? "Add exercises here once, then pick them quickly when logging workouts." : "Add exercises for this workout type, then pick them quickly when logging workouts.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else if filteredExerciseTemplates.isEmpty {
                Section {
                    ContentUnavailableView.search(text: exerciseSearchText)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(groupedExerciseLibraryByType) { typeGroup in
                    Section {
                        ForEach(typeGroup.categories) { categoryGroup in
                            exerciseLibraryCategoryRows(categoryGroup)
                        }
                    } header: {
                        Text(typeGroup.title)
                    }
                }
            }

            Section {
                Button {
                    templateParentSubcategory = nil
                    newExerciseTemplateName = ""
                    showingAddExerciseTemplate = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(relevantSubcategories.isEmpty)
            } footer: {
                if relevantSubcategories.isEmpty {
                    Text("Create a subcategory from Categories before adding library exercises.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Exercise Library")
        .searchable(text: $exerciseSearchText, prompt: "Search exercises")
        .onAppear {
            expandInitialLibraryGroupsIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCategoryTools = true
                } label: {
                    Label("Categories", systemImage: "folder")
                }
            }
        }
        .sheet(isPresented: $showingAddSubcategory) {
            addSubcategorySheet
        }
        .sheet(isPresented: $showingAddExerciseTemplate) {
            addExerciseTemplateSheet
        }
        .sheet(item: $selectedSubcategory) { subcategory in
            subcategorySheet(for: subcategory)
        }
        .sheet(item: $selectedExerciseTemplate) { template in
            exerciseTemplateEditorSheet(for: template)
        }
        .sheet(item: $subcategoryPendingMove) { subcategory in
            moveSubcategoryContentSheet(for: subcategory)
        }
        .sheet(isPresented: $showingCategoryTools) {
            categoryToolsSheet
        }
        .sheet(isPresented: $showingPaywall) {
            CustomPaywallView()
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
        .confirmationDialog(
            "Remove Exercise",
            isPresented: exerciseTemplateDeleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: exerciseTemplatePendingDelete
        ) { template in
            Button(exerciseTemplateDeleteButtonTitle(for: template), role: .destructive) {
                deleteExerciseTemplate(template)
            }
            Button("Cancel", role: .cancel) {
                exerciseTemplatePendingDelete = nil
            }
        } message: { template in
            Text(exerciseTemplateDeleteMessage(for: template))
        }
    }

    private var categoryToolsSheet: some View {
        NavigationStack {
            List {
                if groupedCategories.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Categories Yet",
                            systemImage: "square.grid.2x2",
                            description: Text("Create a category from the workout flow first.")
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
            .navigationTitle("Category Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showingCategoryTools = false
                    }
                }
            }
        }
    }

    private func subcategoriesFor(_ category: WorkoutCategory) -> [WorkoutSubcategory] {
        relevantSubcategories.filter { $0.category?.id == category.id }
    }

    private func exerciseTemplatesFor(_ subcategory: WorkoutSubcategory) -> [SubcategoryExercise] {
        relevantExerciseTemplates
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

    private var exerciseTemplateDeleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { exerciseTemplatePendingDelete != nil },
            set: { if !$0 { exerciseTemplatePendingDelete = nil } }
        )
    }

    private func exerciseTemplateRow(_ template: SubcategoryExercise, showLocation: Bool = true) -> some View {
        Button {
            selectedExerciseTemplate = template
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if showLocation {
                        Text(exerciseTemplateSubtitle(for: template))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                let usageCount = loggedExerciseMatches(for: template).count
                if usageCount > 0 {
                    Text("\(usageCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.12), in: Capsule())
                        .accessibilityLabel("\(usageCount) logged uses")
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                exerciseTemplatePendingDelete = template
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func exerciseLibraryCategoryRows(_ group: ExerciseLibraryCategoryGroup) -> some View {
        DisclosureGroup(
            isExpanded: libraryCategoryExpansionBinding(for: group)
        ) {
            ForEach(group.subcategories) { subgroup in
                exerciseLibrarySubcategoryRows(subgroup)
            }
        } label: {
            HStack {
                Text(categorySortTitle(group))
                    .font(.headline)
                Spacer()
                Text("\(group.subcategories.reduce(0) { $0 + $1.templates.count })")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exerciseLibrarySubcategoryRows(
        _ subgroup: ExerciseLibrarySubcategoryGroup
    ) -> some View {
        DisclosureGroup(
            isExpanded: librarySubcategoryExpansionBinding(for: subgroup)
        ) {
            ForEach(subgroup.templates) { template in
                exerciseTemplateRow(template, showLocation: false)
            }
        } label: {
            HStack {
                Text(subcategorySortTitle(subgroup))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(subgroup.templates.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func libraryCategoryExpansionBinding(for group: ExerciseLibraryCategoryGroup) -> Binding<Bool> {
        Binding(
            get: { expandedLibraryCategoryIDs.contains(group.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedLibraryCategoryIDs.insert(group.id)
                } else {
                    expandedLibraryCategoryIDs.remove(group.id)
                }
            }
        )
    }

    private func librarySubcategoryExpansionBinding(for subgroup: ExerciseLibrarySubcategoryGroup) -> Binding<Bool> {
        Binding(
            get: { expandedLibrarySubcategoryIDs.contains(subgroup.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedLibrarySubcategoryIDs.insert(subgroup.id)
                } else {
                    expandedLibrarySubcategoryIDs.remove(subgroup.id)
                }
            }
        )
    }

    private func expandInitialLibraryGroupsIfNeeded() {
        guard expandedLibraryCategoryIDs.isEmpty,
              expandedLibrarySubcategoryIDs.isEmpty,
              let firstTypeGroup = groupedExerciseLibraryByType.first,
              let firstGroup = firstTypeGroup.categories.first else {
            return
        }

        expandedLibraryCategoryIDs.insert(firstGroup.id)
        if let firstSubcategory = firstGroup.subcategories.first {
            expandedLibrarySubcategoryIDs.insert(firstSubcategory.id)
        }
    }

    private func exerciseTemplateSubtitle(for template: SubcategoryExercise) -> String {
        let subcategory = template.subcategory?.name ?? "Unlinked"
        let category = template.subcategory?.category?.name
        if let category {
            return "\(category) - \(subcategory)"
        }
        return subcategory
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
                    Text("\(subcategoriesFor(category).count) subcategories in \(category.resolvedWorkoutType?.rawValue ?? category.activityDisplayName)")
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
        let templates = exerciseTemplatesFor(subcategory)

        return NavigationStack {
            List {
                Section {
                    LabeledContent("Parent Category", value: subcategory.category?.name ?? "Unlinked")
                    LabeledContent("Workout Type", value: subcategory.category?.resolvedWorkoutType?.rawValue ?? subcategory.category?.activityDisplayName ?? "Unspecified")
                    LabeledContent("Exercises", value: "\(exerciseTemplatesFor(subcategory).count)")
                }

                Section("Exercises") {
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
                            Button {
                                selectedExerciseTemplate = template
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.subheadline)
                                        Text("\(loggedExerciseMatches(for: template).count) logged uses")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    exerciseTemplatePendingDelete = template
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section {
                    if !(templates.isEmpty && (subcategory.exercises?.isEmpty ?? true)) {
                        Button {
                            subcategoryPendingMove = subcategory
                        } label: {
                            Label("Move Exercises to Another Subcategory", systemImage: "arrow.right.arrow.left")
                        }
                    }

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
            .navigationTitle("Subcategory")
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

    private func exerciseTemplateDeleteButtonTitle(for template: SubcategoryExercise) -> String {
        loggedExerciseMatches(for: template).isEmpty ? "Delete Exercise" : "Remove from Library"
    }

    private func exerciseTemplateDeleteMessage(for template: SubcategoryExercise) -> String {
        let matches = loggedExerciseMatches(for: template)
        guard !matches.isEmpty else {
            return "\(template.name) is not used in workout history. Deleting it removes it from future exercise pickers."
        }

        let latest = latestLoggedDate(for: template).map {
            $0.formatted(date: .abbreviated, time: .omitted)
        }
        let latestSentence = latest.map { " Last used \($0)." } ?? ""
        return "\(template.name) appears in \(matches.count) logged workout exercise\(matches.count == 1 ? "" : "s"). Removing it from the library will not delete or rename workout history.\(latestSentence)"
    }

    private func loggedExerciseMatches(for template: SubcategoryExercise) -> [WorkoutExercise] {
        let templateName = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !templateName.isEmpty else { return [] }
        return workouts.flatMap { $0.exercises ?? [] }.filter { exercise in
            exercise.subcategory?.id == template.subcategory?.id &&
            exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(templateName) == .orderedSame
        }
    }

    private func workoutsMatchingExerciseTemplate(_ template: SubcategoryExercise) -> [Workout] {
        let matches = Set(loggedExerciseMatches(for: template).map(\.id))
        return workouts.filter { workout in
            (workout.exercises ?? []).contains { matches.contains($0.id) }
        }
    }

    private func latestLoggedDate(for template: SubcategoryExercise) -> Date? {
        workoutsMatchingExerciseTemplate(template).map(\.startDate).max()
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

    private func moveSubcategoryContent(_ source: WorkoutSubcategory, to destination: WorkoutSubcategory) {
        guard source.id != destination.id else { return }

        for template in exerciseTemplatesFor(source) {
            template.subcategory = destination
        }

        for exercise in source.exercises ?? [] {
            exercise.subcategory = destination
        }

        try? modelContext.save()
        subcategoryPendingMove = nil
    }

    private func deleteExerciseTemplate(_ template: SubcategoryExercise) {
        if selectedExerciseTemplate?.id == template.id {
            selectedExerciseTemplate = nil
        }
        modelContext.delete(template)
        try? modelContext.save()
        exerciseTemplatePendingDelete = nil
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

    private func moveSubcategoryContentSheet(for source: WorkoutSubcategory) -> some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Exercise templates", value: "\(exerciseTemplatesFor(source).count)")
                    LabeledContent("Logged exercises", value: "\(source.exercises?.count ?? 0)")
                } footer: {
                    Text("This keeps workout history and library exercises intact, but moves their subcategory link.")
                }

                Section("Move to") {
                    ForEach(relevantSubcategories.filter { $0.id != source.id }) { destination in
                        Button {
                            moveSubcategoryContent(source, to: destination)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination.name)
                                        .foregroundStyle(.primary)
                                    if let categoryName = destination.category?.name {
                                        Text(categoryName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Move Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        subcategoryPendingMove = nil
                    }
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
                } else {
                    Section("Subcategory") {
                        ForEach(relevantSubcategories) { subcategory in
                            Button {
                                templateParentSubcategory = subcategory
                            } label: {
                                HStack {
                                    Text(subcategory.name)
                                    Spacer()
                                    if templateParentSubcategory?.id == subcategory.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
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
                    .disabled(
                        newExerciseTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        templateParentSubcategory == nil
                    )
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
        let exists = exerciseTemplatesFor(subcategory).contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame
        }
        guard !exists else {
            newExerciseTemplateName = ""
            templateParentSubcategory = nil
            showingAddExerciseTemplate = false
            return
        }
        let order = exerciseTemplatesFor(subcategory).count
        let template = SubcategoryExercise(name: name, subcategory: subcategory, orderIndex: order)
        modelContext.insert(template)
        try? modelContext.save()
        newExerciseTemplateName = ""
        templateParentSubcategory = nil
        showingAddExerciseTemplate = false
    }

    private func exerciseTemplateEditorSheet(for template: SubcategoryExercise) -> some View {
        ExerciseTemplateEditorSheet(template: template, availableSubcategories: relevantSubcategories)
    }
}

private struct ExerciseTemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    let template: SubcategoryExercise
    let availableSubcategories: [WorkoutSubcategory]
    @State private var draftName: String
    @State private var selectedSubcategoryID: UUID?
    @State private var renameMatchingHistory = false
    @State private var showingRemoveConfirmation = false

    init(template: SubcategoryExercise, availableSubcategories: [WorkoutSubcategory]) {
        self.template = template
        self.availableSubcategories = availableSubcategories
        _draftName = State(initialValue: template.name)
        _selectedSubcategoryID = State(initialValue: template.subcategory?.id)
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingExercises: [WorkoutExercise] {
        let originalName = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalName.isEmpty else { return [] }
        return workouts.flatMap { $0.exercises ?? [] }.filter { exercise in
            exercise.subcategory?.id == template.subcategory?.id &&
            exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(originalName) == .orderedSame
        }
    }

    private var latestUseText: String {
        let matchingIDs = Set(matchingExercises.map(\.id))
        let latest = workouts
            .filter { workout in
                (workout.exercises ?? []).contains { matchingIDs.contains($0.id) }
            }
            .map(\.startDate)
            .max()

        guard let latest else { return "Never logged" }
        return latest.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $draftName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    Picker("Subcategory", selection: $selectedSubcategoryID) {
                        ForEach(availableSubcategories) { subcategory in
                            Text(subcategory.name).tag(Optional(subcategory.id))
                        }
                    }
                }

                Section {
                    LabeledContent("Logged uses", value: "\(matchingExercises.count)")
                    LabeledContent("Last used", value: latestUseText)
                } header: {
                    Text("Usage")
                } footer: {
                    Text("Library changes affect future exercise pickers. Workout history is only changed if you turn on history renaming.")
                }

                if !matchingExercises.isEmpty {
                    Section {
                        Toggle("Also rename matching history", isOn: $renameMatchingHistory)
                    } footer: {
                        Text("This updates logged exercises with the current name in this subcategory. It does not touch exercises in other subcategories.")
                    }
                }

                Section {
                    Button(matchingExercises.isEmpty ? "Delete Exercise" : "Remove from Library", role: .destructive) {
                        showingRemoveConfirmation = true
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty || selectedSubcategoryID == nil)
                }
            }
            .confirmationDialog(
                matchingExercises.isEmpty ? "Delete Exercise" : "Remove Exercise",
                isPresented: $showingRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button(matchingExercises.isEmpty ? "Delete Exercise" : "Remove from Library", role: .destructive) {
                    modelContext.delete(template)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if matchingExercises.isEmpty {
                    Text("This removes \(template.name) from future exercise pickers.")
                } else {
                    Text("\(template.name) appears in \(matchingExercises.count) logged workout exercise\(matchingExercises.count == 1 ? "" : "s"). Removing it from the library will keep workout history unchanged.")
                }
            }
        }
    }

    private func save() {
        guard let selectedSubcategoryID,
              let subcategory = availableSubcategories.first(where: { $0.id == selectedSubcategoryID }) else {
            return
        }

        if renameMatchingHistory {
            for exercise in matchingExercises {
                exercise.name = trimmedName
                exercise.subcategory = subcategory
            }
        }

        template.name = trimmedName
        template.subcategory = subcategory
        try? modelContext.save()
        dismiss()
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
