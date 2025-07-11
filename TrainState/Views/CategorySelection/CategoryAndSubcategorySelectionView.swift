import SwiftUI
import SwiftData

struct CategoryAndSubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedCategories: [WorkoutCategory]
    @Binding var selectedSubcategories: [WorkoutSubcategory]

    let workoutType: WorkoutType

    @Query private var allWorkoutCategoriesFromDB: [WorkoutCategory]
    @Query private var allPersistedSubcategories: [WorkoutSubcategory]

    // View State
    @State private var searchText = ""
    @State private var showingAddCategorySheet = false

    // Memoized/Cached Data
    @State private var cachedCategories: [WorkoutCategory] = []
    @State private var cachedSubcategoryOptions: [String: [WorkoutSubcategory]] = [:]
    
    // Optimized: Pre-computed sets for fast lookups
    @State private var selectedCategoryIDSet: Set<UUID> = []
    @State private var selectedSubcategoryIDSet: Set<UUID> = []

    private var workoutTypeColor: Color {
        WorkoutTypeHelper.colorForType(workoutType)
    }

    private var searchResults: [WorkoutCategory] {
        if searchText.isEmpty {
            return cachedCategories
        }
        return cachedCategories.filter { category in
            category.name.localizedCaseInsensitiveContains(searchText) ||
            (cachedSubcategoryOptions[category.name]?.contains { $0.name.localizedCaseInsensitiveContains(searchText) } ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Simplified header
            headerView
            
            // Optimized list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if searchResults.isEmpty && !searchText.isEmpty {
                        noSearchResultsView
                    } else {
                        ForEach(searchResults) { category in
                            categoryCard(for: category)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search categories or exercises")
        .onAppear(perform: initialSetup)
        .onChange(of: allWorkoutCategoriesFromDB) { _, _ in updateCachedData() }
        .onChange(of: workoutType) { _, _ in updateCachedData() }
        .onChange(of: selectedCategories) { _, _ in updateSelectedSets() }
        .onChange(of: selectedSubcategories) { _, _ in updateSelectedSets() }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            AddNewCategorySheet(
                workoutType: workoutType,
                onSave: { newCategory in
                    selectedCategories.append(newCategory)
                }
            )
        }
    }

    // MARK: - Simplified Header
    private var headerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(workoutTypeColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: WorkoutTypeHelper.iconForType(workoutType))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Organize \(workoutType.rawValue.capitalized)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("\(selectedCategories.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(workoutTypeColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - Optimized Category Card
    private func categoryCard(for category: WorkoutCategory) -> some View {
        let isSelected = selectedCategoryIDSet.contains(category.id)
        let categoryColor = Color(hex: category.color) ?? workoutTypeColor
        
        return VStack(spacing: 0) {
            Button(action: { toggleCategory(category) }) {
                HStack(spacing: 12) {
                    // Simple checkbox
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? categoryColor : Color(.systemGray5))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(isSelected ? 1 : 0)
                        )
                    
                    Text(category.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if let subcategories = cachedSubcategoryOptions[category.name], !subcategories.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isSelected ? 180 : 0))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? categoryColor.opacity(0.1) : Color(.systemGray6))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Subcategories
            if isSelected {
                let subcategories = cachedSubcategoryOptions[category.name] ?? []
                if !subcategories.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(subcategories) { subcategory in
                            subcategoryRow(subcategory, categoryColor: categoryColor)
                            if subcategory.id != subcategories.last?.id {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Optimized Subcategory Row
    private func subcategoryRow(_ subcategory: WorkoutSubcategory, categoryColor: Color) -> some View {
        let isSelected = selectedSubcategoryIDSet.contains(subcategory.id)
        
        return Button(action: { toggleSubcategory(subcategory) }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? categoryColor : Color(.systemGray5))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
                
                Text(subcategory.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? categoryColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: { showingAddCategorySheet = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(workoutTypeColor)
                .clipShape(Circle())
                .shadow(radius: 8)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Optimized Helper Methods
    private func initialSetup() {
        updateCachedData()
        updateSelectedSets()
    }

    private func updateCachedData() {
        cachedCategories = allWorkoutCategoriesFromDB.filter { $0.workoutType == workoutType }
        var options: [String: [WorkoutSubcategory]] = [:]
        for category in cachedCategories {
            let subs = (category.subcategories ?? []).sorted { $0.name < $1.name }
            if !subs.isEmpty {
                options[category.name] = subs
            }
        }
        cachedSubcategoryOptions = options
    }
    
    private func updateSelectedSets() {
        selectedCategoryIDSet = Set(selectedCategories.map { $0.id })
        selectedSubcategoryIDSet = Set(selectedSubcategories.map { $0.id })
    }

    private func toggleCategory(_ category: WorkoutCategory) {
        if let idx = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: idx)
        } else {
            selectedCategories.append(category)
        }
    }

    private func toggleSubcategory(_ subcategory: WorkoutSubcategory) {
        if let idx = selectedSubcategories.firstIndex(where: { $0.id == subcategory.id }) {
            selectedSubcategories.remove(at: idx)
        } else {
            selectedSubcategories.append(subcategory)
        }
    }
}

// MARK: - Add New Category Sheet
private struct AddNewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let workoutType: WorkoutType
    var onSave: (WorkoutCategory) -> Void
    
    @State private var newCategoryName = ""
    @State private var newCategoryColor: Color
    
    private var workoutTypeColor: Color {
        WorkoutTypeHelper.colorForType(workoutType)
    }
    
    init(workoutType: WorkoutType, onSave: @escaping (WorkoutCategory) -> Void) {
        self.workoutType = workoutType
        self.onSave = onSave
        _newCategoryColor = State(initialValue: WorkoutTypeHelper.colorForType(workoutType))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $newCategoryName)
                    ColorPicker("Category Color", selection: $newCategoryColor, supportsOpacity: false)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: addNewCategory)
                        .fontWeight(.semibold)
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addNewCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newCategory = WorkoutCategory(
            name: trimmedName,
            color: newCategoryColor.toHex() ?? "#0000FF",
            workoutType: workoutType
        )
        
        modelContext.insert(newCategory)
        do {
            try modelContext.save()
            onSave(newCategory)
            dismiss()
        } catch {
            print("Failed to save new category: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedCategories: [WorkoutCategory] = []
        @State private var selectedSubcategories: [WorkoutSubcategory] = []
        
        var body: some View {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
            
            // Sample Data
            let sampleCat1 = WorkoutCategory(name: "Legs", color: "D532FF", workoutType: .strength)
            let sampleCat2 = WorkoutCategory(name: "Chest", color: "326AFF", workoutType: .strength)
            let sampleSub1 = WorkoutSubcategory(name: "Squats")
            sampleSub1.category = sampleCat1
            let sampleSub2 = WorkoutSubcategory(name: "Lunges")
            sampleSub2.category = sampleCat1
            let sampleSub3 = WorkoutSubcategory(name: "Bench Press")
            sampleSub3.category = sampleCat2

            container.mainContext.insert(sampleCat1)
            container.mainContext.insert(sampleCat2)
            container.mainContext.insert(sampleSub1)
            container.mainContext.insert(sampleSub2)
            container.mainContext.insert(sampleSub3)

            return CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategories,
                selectedSubcategories: $selectedSubcategories,
                workoutType: .strength
            )
            .modelContainer(container)
        }
    }
    
    return PreviewWrapper()
} 
