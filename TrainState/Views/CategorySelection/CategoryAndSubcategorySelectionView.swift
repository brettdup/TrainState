import SwiftUI
import SwiftData
import RevenueCatUI

struct CategoryAndSubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedCategories: [WorkoutCategory]
    @Binding var selectedSubcategories: [WorkoutSubcategory]
    let workoutType: WorkoutType

    @Query private var allWorkoutCategories: [WorkoutCategory]
    @Query private var allSubcategories: [WorkoutSubcategory]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showingAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var subcategoryParentCategory: WorkoutCategory?
    @State private var showingPaywall = false

    private var canAddCategory: Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || allWorkoutCategories.count < PremiumLimits.freeCategoryLimit
    }

    private func canAddSubcategory(to category: WorkoutCategory) -> Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || subcategoriesFor(category).count < PremiumLimits.freeSubcategoryPerCategoryLimit
    }

    var body: some View {
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

            List {
                Section("Categories") {
                    ForEach(filteredCategories) { category in
                        Toggle(category.name, isOn: categoryBinding(category))
                    }
                }

                ForEach(selectedCategories) { category in
                    Section {
                        ForEach(subcategoriesFor(category)) { subcategory in
                            Toggle(isOn: subcategoryBinding(subcategory)) {
                                SubcategoryRow(subcategory: subcategory, category: category)
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
                            Label("Add Subcategory", systemImage: "plus.circle")
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: category.color) ?? .gray)
                                .frame(width: 8, height: 8)
                            Text(category.name)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if canAddCategory {
                            showingAddCategory = true
                        } else {
                            Task {
                                await purchaseManager.loadProducts()
                                await purchaseManager.updatePurchasedProducts()
                                showingPaywall = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
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
                            TextField("Category name", text: $newCategoryName)
                                .textFieldStyle(.plain)
                                .padding(20)
                                .glassCard()
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }
                    }
                    .navigationTitle("New Category")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                newCategoryName = ""
                                showingAddCategory = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                addCategory()
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSubcategory) {
                addSubcategorySheet
            }
            .sheet(isPresented: $showingPaywall) {
                if let offering = purchaseManager.offerings?.current {
                    PaywallView(offering: offering)
                } else {
                    PaywallPlaceholderView(onDismiss: { showingPaywall = false })
                }
            }
        }
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
                            Label("Will be added to \(cat.name)", systemImage: "link")
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

    private var filteredCategories: [WorkoutCategory] {
        allWorkoutCategories.filter { $0.workoutType == workoutType }
    }

    private func subcategoriesFor(_ category: WorkoutCategory) -> [WorkoutSubcategory] {
        allSubcategories.filter { $0.category?.id == category.id }
    }

    private func categoryBinding(_ category: WorkoutCategory) -> Binding<Bool> {
        Binding(
            get: { selectedCategories.contains(where: { $0.id == category.id }) },
            set: { isOn in
                if isOn {
                    selectedCategories.append(category)
                } else {
                    selectedCategories.removeAll { $0.id == category.id }
                    selectedSubcategories.removeAll { $0.category?.id == category.id }
                }
            }
        )
    }

    private func subcategoryBinding(_ subcategory: WorkoutSubcategory) -> Binding<Bool> {
        Binding(
            get: { selectedSubcategories.contains(where: { $0.id == subcategory.id }) },
            set: { isOn in
                if isOn {
                    selectedSubcategories.append(subcategory)
                } else {
                    selectedSubcategories.removeAll { $0.id == subcategory.id }
                }
            }
        )
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let category = WorkoutCategory(name: name, workoutType: workoutType)
        modelContext.insert(category)
        try? modelContext.save()
        selectedCategories.append(category)
        newCategoryName = ""
        showingAddCategory = false
    }

    private func addSubcategory() {
        let name = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let category = subcategoryParentCategory else { return }
        let sub = WorkoutSubcategory(name: name, category: category)
        modelContext.insert(sub)
        try? modelContext.save()
        DataInitializationManager.shared.initializeDefaultExerciseTemplatesIfNeeded(context: modelContext)
        selectedSubcategories.append(sub)
        newSubcategoryName = ""
        showingAddSubcategory = false
        subcategoryParentCategory = nil
    }
}

// MARK: - Subcategory Row
private struct SubcategoryRow: View {
    let subcategory: WorkoutSubcategory
    let category: WorkoutCategory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: category.color) ?? .secondary)
            Text(subcategory.name)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    let context = container.mainContext

    let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
    let pull = WorkoutCategory(name: "Pull", color: "#4ECDC4", workoutType: .strength)
    context.insert(push)
    context.insert(pull)

    let benchPress = WorkoutSubcategory(name: "Bench Press", category: push)
    context.insert(benchPress)
    let row = WorkoutSubcategory(name: "Row", category: pull)
    context.insert(row)

    return CategoryAndSubcategorySelectionView(
        selectedCategories: .constant([push]),
        selectedSubcategories: .constant([]),
        workoutType: .strength
    )
    .modelContainer(container)
}
