import SwiftUI
import SwiftData
import RevenueCatUI
import HealthKit

struct CategoryAndSubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedCategories: [WorkoutCategory]
    @Binding var selectedSubcategories: [WorkoutSubcategory]
    let workoutType: WorkoutType
    let appleWorkoutActivityType: HKWorkoutActivityType?

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
            List {
                Section {
                    Text(activityDisplayName)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Workout Type")
                }

                Section {
                    if filteredCategories.isEmpty {
                        ContentUnavailableView(
                            "No Categories Yet",
                            systemImage: "tag",
                            description: Text("Add a category for this workout type to get started.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredCategories) { category in
                            Button {
                                toggleCategory(category)
                            } label: {
                                CategorySelectionRow(
                                    category: category,
                                    isSelected: isCategorySelected(category)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Choose one or more categories for this workout.")
                }

                ForEach(selectedCategories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { category in
                    Section {
                        let subcategories = subcategoriesFor(category)

                        if subcategories.isEmpty {
                            Text("No subcategories yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(subcategories) { subcategory in
                                Button {
                                    toggleSubcategory(subcategory)
                                } label: {
                                    SubcategorySelectionRow(
                                        subcategory: subcategory,
                                        category: category,
                                        isSelected: isSubcategorySelected(subcategory)
                                    )
                                }
                                .buttonStyle(.plain)
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
                    } footer: {
                        Text("Pick the more specific subcategories that apply.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
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
                    Form {
                        Section("Category") {
                            TextField("Category name", text: $newCategoryName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }

                        Section("Workout Type") {
                            Text(activityDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("New Category")
                    .navigationBarTitleDisplayMode(.inline)
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
                NavigationStack {
                    Form {
                        Section("Subcategory") {
                            TextField("Subcategory name", text: $newSubcategoryName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }

                        if let category = subcategoryParentCategory {
                            Section("Parent Category") {
                                Text(category.name)
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
            .sheet(isPresented: $showingPaywall) {
                if let offering = purchaseManager.offerings?.current {
                    PaywallView(offering: offering)
                } else {
                    PaywallPlaceholderView(onDismiss: { showingPaywall = false })
                }
            }
        }
    }

    private var activityDisplayName: String {
        appleWorkoutActivityType?.displayName ?? workoutType.rawValue
    }

    private var filteredCategories: [WorkoutCategory] {
        WorkoutCategory.categoriesForAppleWorkout(
            activityType: appleWorkoutActivityType,
            fallbackWorkoutType: workoutType,
            from: allWorkoutCategories
        )
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func subcategoriesFor(_ category: WorkoutCategory) -> [WorkoutSubcategory] {
        allSubcategories
            .filter { $0.category?.id == category.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isCategorySelected(_ category: WorkoutCategory) -> Bool {
        selectedCategories.contains(where: { $0.id == category.id })
    }

    private func isSubcategorySelected(_ subcategory: WorkoutSubcategory) -> Bool {
        selectedSubcategories.contains(where: { $0.id == subcategory.id })
    }

    private func toggleCategory(_ category: WorkoutCategory) {
        if isCategorySelected(category) {
            selectedCategories.removeAll { $0.id == category.id }
            selectedSubcategories.removeAll { $0.category?.id == category.id }
        } else {
            selectedCategories.append(category)
        }
    }

    private func toggleSubcategory(_ subcategory: WorkoutSubcategory) {
        if isSubcategorySelected(subcategory) {
            selectedSubcategories.removeAll { $0.id == subcategory.id }
        } else {
            selectedSubcategories.append(subcategory)
        }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let category = WorkoutCategory(
            name: name,
            workoutType: workoutType,
            appleWorkoutActivityType: appleWorkoutActivityType
        )
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

private struct CategorySelectionRow: View {
    let category: WorkoutCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: category.color) ?? .gray)
                .frame(width: 10, height: 10)

            Text(category.name)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

private struct SubcategorySelectionRow: View {
    let subcategory: WorkoutSubcategory
    let category: WorkoutCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: category.color) ?? .secondary)

            Text(subcategory.name)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

@MainActor
private func makeCategorySelectionPreviewData() -> (container: ModelContainer, push: WorkoutCategory) {
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

    return (container, push)
}

#Preview {
    let preview = makeCategorySelectionPreviewData()

    CategoryAndSubcategorySelectionView(
        selectedCategories: .constant([preview.push]),
        selectedSubcategories: .constant([]),
        workoutType: .strength,
        appleWorkoutActivityType: .traditionalStrengthTraining
    )
    .modelContainer(preview.container)
}
