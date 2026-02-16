import SwiftUI
import SwiftData
import RevenueCatUI

struct CategoriesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutCategory.name) private var categories: [WorkoutCategory]
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var expandedCategoryId: UUID?
    @State private var expandedSubcategoryId: UUID?
    @State private var showingAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var subcategoryParentCategory: WorkoutCategory?
    @State private var showingAddExerciseTemplate = false
    @State private var newExerciseTemplateName = ""
    @State private var templateParentSubcategory: WorkoutSubcategory?
    @State private var showingPaywall = false

    private var groupedCategories: [(id: String, title: String, categories: [WorkoutCategory])] {
        let grouped = Dictionary(grouping: categories) { $0.workoutType }
        var sections: [(id: String, title: String, categories: [WorkoutCategory])] = WorkoutType.allCases.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            return (id: type.rawValue, title: type.rawValue, categories: items.sorted { $0.name < $1.name })
        }

        if let uncategorized = grouped[nil], !uncategorized.isEmpty {
            sections.append((id: "unspecified", title: "Unspecified", categories: uncategorized.sorted { $0.name < $1.name }))
        }

        return sections
    }

    private func canAddSubcategory(to category: WorkoutCategory) -> Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || subcategoriesFor(category).count < PremiumLimits.freeSubcategoryPerCategoryLimit
    }

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
                VStack(alignment: .leading, spacing: 20) {
                    Text("Subcategories are linked to their parent category. Expand a subcategory to manage its exercises.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(groupedCategories, id: \.id) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(section.categories) { category in
                                DisclosureGroup(isExpanded: Binding(
                                    get: { expandedCategoryId == category.id },
                                    set: { expandedCategoryId = $0 ? category.id : nil }
                                )) {
                                    ForEach(subcategoriesFor(category)) { sub in
                                        DisclosureGroup(isExpanded: Binding(
                                            get: { expandedSubcategoryId == sub.id },
                                            set: { expandedSubcategoryId = $0 ? sub.id : nil }
                                        )) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ForEach(exerciseTemplatesFor(sub)) { template in
                                                    HStack(spacing: 8) {
                                                        Image(systemName: "dumbbell.fill")
                                                            .font(.caption2)
                                                            .foregroundStyle(.tertiary)
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
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                Button {
                                                    templateParentSubcategory = sub
                                                    newExerciseTemplateName = ""
                                                    showingAddExerciseTemplate = true
                                                } label: {
                                                    Label("Add Exercise", systemImage: "plus.circle")
                                                        .font(.subheadline)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.top, 4)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.turn.down.right")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                                Text(sub.name)
                                                    .font(.subheadline)
                                                Spacer()
                                                Text("\(exerciseTemplatesFor(sub).count)")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
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
                                        Label("Add Subcategory", systemImage: "plus.circle")
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: category.color) ?? .gray)
                                            .frame(width: 10, height: 10)
                                        Text(category.name)
                                            .font(.headline)
                                    }
                                }
                                .padding(20)
                                .glassCard()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Categories")
        .sheet(isPresented: $showingAddSubcategory) {
            addSubcategorySheet
        }
        .sheet(isPresented: $showingAddExerciseTemplate) {
            addExerciseTemplateSheet
        }
        .sheet(isPresented: $showingPaywall) {
            if let offering = purchaseManager.offerings?.current {
                PaywallView(offering: offering)
            } else {
                PaywallPlaceholderView(onDismiss: { showingPaywall = false })
            }
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

    private var addSubcategorySheet: some View {
        NavigationStack {
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
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Subcategory name", text: $newSubcategoryName)
                            .textFieldStyle(.plain)
                            .padding(20)
                            .glassCard()
                        if let cat = subcategoryParentCategory {
                            Label("Will be linked to \(cat.name)", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("New Subcategory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSubcategory = false
                        subcategoryParentCategory = nil
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
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Exercise name", text: $newExerciseTemplateName)
                            .textFieldStyle(.plain)
                            .padding(20)
                            .glassCard()
                        if let subcategory = templateParentSubcategory {
                            Label("Will be linked to \(subcategory.name)", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("New Exercise")
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
