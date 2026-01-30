import SwiftUI
import SwiftData

struct CategoryAndSubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedCategories: [WorkoutCategory]
    @Binding var selectedSubcategories: [WorkoutSubcategory]
    let workoutType: WorkoutType

    @Query private var allWorkoutCategories: [WorkoutCategory]
    @Query private var allSubcategories: [WorkoutSubcategory]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Categories") {
                    ForEach(filteredCategories) { category in
                        Button {
                            toggleCategory(category)
                        } label: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                if selectedCategories.contains(where: { $0.id == category.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Subcategories") {
                    ForEach(filteredSubcategories) { subcategory in
                        Button {
                            toggleSubcategory(subcategory)
                        } label: {
                            HStack {
                                Text(subcategory.name)
                                Spacer()
                                if selectedSubcategories.contains(where: { $0.id == subcategory.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddCategory = true
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
                        TextField("Category name", text: $newCategoryName)
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
        }
    }

    private var filteredCategories: [WorkoutCategory] {
        allWorkoutCategories.filter { $0.workoutType == workoutType }
    }

    private var filteredSubcategories: [WorkoutSubcategory] {
        let categoryIDs = Set(selectedCategories.map(\.id))
        return allSubcategories.filter { subcategory in
            guard let category = subcategory.category else { return false }
            return categoryIDs.contains(category.id)
        }
    }

    private func toggleCategory(_ category: WorkoutCategory) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
            selectedSubcategories.removeAll { $0.category?.id == category.id }
        } else {
            selectedCategories.append(category)
        }
    }

    private func toggleSubcategory(_ subcategory: WorkoutSubcategory) {
        if let index = selectedSubcategories.firstIndex(where: { $0.id == subcategory.id }) {
            selectedSubcategories.remove(at: index)
        } else {
            selectedSubcategories.append(subcategory)
        }
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
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    return CategoryAndSubcategorySelectionView(
        selectedCategories: .constant([]),
        selectedSubcategories: .constant([]),
        workoutType: .strength
    )
    .modelContainer(container)
}
