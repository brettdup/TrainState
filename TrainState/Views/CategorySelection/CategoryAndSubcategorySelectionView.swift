import SwiftUI
import SwiftData

struct CategoryAndSubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedCategories: [WorkoutCategory]
    @Binding var selectedSubcategories: [WorkoutSubcategory]
    @Query private var allWorkoutCategoriesFromDB: [WorkoutCategory]
    @Query private var allPersistedSubcategories: [WorkoutSubcategory]
    let workoutType: WorkoutType
    
    @State private var selectedTab: Int = 0
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue
    
    // Memoized filtered categories and subcategory options
    @State private var cachedCategories: [WorkoutCategory] = []
    @State private var cachedSubcategoryOptions: [String: [WorkoutSubcategory]] = [:]
    
    // Use Set for fast lookup
    private var selectedCategoryIDs: Set<UUID> { Set(selectedCategories.map { $0.id }) }
    private var selectedSubcategoryIDs: Set<UUID> { Set(selectedSubcategories.map { $0.id }) }
    
    // Get categories for the specific workout type
    var filteredPrimaryCategories: [WorkoutCategory] {
        cachedCategories
    }
    
    // Subcategory options from persisted entities, mapped by parent category name
    var subcategoryOptions: [String: [WorkoutSubcategory]] {
        cachedSubcategoryOptions
    }
    
    // Only show subcategories for selected categories
    var selectedCategorySubcategoryOptions: [String: [WorkoutSubcategory]] {
        var options: [String: [WorkoutSubcategory]] = [:]
        for category in selectedCategories {
            if let subs = subcategoryOptions[category.name], !subs.isEmpty {
                options[category.name] = subs
            }
        }
        return options
    }
    
    var workoutTypeColor: Color {
        switch workoutType {
        case .strength: return .purple
        case .cardio: return .red
        case .yoga: return .mint
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .other: return .orange
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sleek header
                headerSection
                
                // Modern segmented control
                segmentedControl
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // Add category form (if showing)
                if showingAddCategory {
                    addCategoryForm
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Content area
                TabView(selection: $selectedTab) {
                    // Categories Tab
                    categoriesTab
                        .tag(0)
                    
                    // Subcategories Tab
                    subcategoriesTab
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        cleanupSubcategories()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(workoutTypeColor)
                }
            }
        }
        .onAppear {
            updateCachedData()
        }
        .onChange(of: allWorkoutCategoriesFromDB) { _ in
            updateCachedData()
        }
        .onChange(of: workoutType) { _ in
            updateCachedData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon and title
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(workoutTypeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: WorkoutTypeHelper.iconForType(workoutType))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(workoutTypeColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Organize Your Workout")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("\(workoutType.rawValue.capitalized) • \(selectedCategories.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(["Categories", "Exercises"], id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab == "Categories" ? 0 : 1
                    }
                }) {
                    Text(tab)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedTab == (tab == "Categories" ? 0 : 1) ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == (tab == "Categories" ? 0 : 1) ? workoutTypeColor : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Categories Tab
    private var categoriesTab: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(filteredPrimaryCategories, id: \.id) { category in
                    CategoryCard(
                        category: category,
                        isSelected: selectedCategoryIDs.contains(category.id),
                        workoutTypeColor: workoutTypeColor,
                        onTap: { toggleCategory(category) }
                    )
                }
                
                // Add category card
                AddCategoryCard(
                    workoutTypeColor: workoutTypeColor,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingAddCategory.toggle()
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Subcategories Tab
    private var subcategoriesTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if selectedCategories.isEmpty {
                    emptyStateView
                } else {
                    ForEach(selectedCategories, id: \.id) { category in
                        if let subs = selectedCategorySubcategoryOptions[category.name], !subs.isEmpty {
                            SubcategorySection(
                                category: category,
                                subcategories: subs,
                                selectedSubcategories: selectedSubcategories,
                                workoutTypeColor: workoutTypeColor,
                                onSubcategoryTap: { sub in
                                    toggleSubcategory(sub, for: category)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("No Categories Selected")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Text("Select categories from the Categories tab to see their exercises")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Add Category Form
    private var addCategoryForm: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Category")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingAddCategory = false
                        newCategoryName = ""
                        newCategoryColor = workoutTypeColor
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                TextField("Category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                
                HStack {
                    ColorPicker("Color", selection: $newCategoryColor, supportsOpacity: false)
                        .labelsHidden()
                    
                    Spacer()
                    
                    Button("Add") {
                        addNewCategory()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(workoutTypeColor)
                    )
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    private func updateCachedData() {
        let filtered = allWorkoutCategoriesFromDB.filter { $0.workoutType == workoutType }
        cachedCategories = filtered
        var options: [String: [WorkoutSubcategory]] = [:]
        for category in filtered {
            let subsForThisCategory = (category.subcategories ?? []).sorted { $0.name < $1.name }
            if !subsForThisCategory.isEmpty {
                options[category.name] = subsForThisCategory
            }
        }
        cachedSubcategoryOptions = options
    }
    
    private func addNewCategory() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newCategory = WorkoutCategory(
            name: trimmedName,
            color: newCategoryColor.toHex() ?? workoutTypeColor.toHex() ?? "#0000FF",
            workoutType: workoutType
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            modelContext.insert(newCategory)
            try? modelContext.save()
            
            selectedCategories.append(newCategory)
            
            showingAddCategory = false
            newCategoryName = ""
            newCategoryColor = workoutTypeColor
        }
    }
    
    private func cleanupSubcategories() {
        selectedSubcategories.removeAll { sub in
            let belongsToSelectedCategory = selectedCategories.contains { category in
                (category.subcategories ?? []).contains { $0.id == sub.id }
            }
            return !belongsToSelectedCategory
        }
        try? modelContext.save()
    }
    
    private func toggleCategory(_ category: WorkoutCategory) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if let idx = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: idx)
            selectedSubcategories.removeAll { sub in
                (category.subcategories ?? []).contains { $0.id == sub.id }
            }
        } else {
            selectedCategories.append(category)
        }
    }
    
    private func toggleSubcategory(_ sub: WorkoutSubcategory, for category: WorkoutCategory) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if !selectedCategories.contains(where: { $0.id == category.id }) {
            return
        }
        
        if let idx = selectedSubcategories.firstIndex(where: { $0.id == sub.id }) {
            selectedSubcategories.remove(at: idx)
        } else {
            if (category.subcategories ?? []).contains(where: { $0.id == sub.id }) {
                selectedSubcategories.append(sub)
            }
        }
    }
}

// MARK: - Supporting Views

private struct CategoryCard: View, Equatable {
    let category: WorkoutCategory
    let isSelected: Bool
    let workoutTypeColor: Color
    let onTap: () -> Void
    
    static func == (lhs: CategoryCard, rhs: CategoryCard) -> Bool {
        lhs.category.id == rhs.category.id && lhs.isSelected == rhs.isSelected
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: category.color) ?? workoutTypeColor)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                // Title
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(workoutTypeColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? workoutTypeColor : Color(.systemGray4),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AddCategoryCard: View {
    let workoutTypeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(workoutTypeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(workoutTypeColor)
                }
                
                Text("Add Category")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SubcategorySection: View, Equatable {
    let category: WorkoutCategory
    let subcategories: [WorkoutSubcategory]
    let selectedSubcategories: [WorkoutSubcategory]
    let workoutTypeColor: Color
    let onSubcategoryTap: (WorkoutSubcategory) -> Void
    
    static func == (lhs: SubcategorySection, rhs: SubcategorySection) -> Bool {
        lhs.category.id == rhs.category.id &&
        lhs.subcategories.map { $0.id } == rhs.subcategories.map { $0.id } &&
        lhs.selectedSubcategories.map { $0.id } == rhs.selectedSubcategories.map { $0.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: category.color) ?? workoutTypeColor)
                    .frame(width: 16, height: 16)
                
                Text(category.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(subcategories.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
            
            // Subcategories
            LazyVStack(spacing: 8) {
                ForEach(subcategories, id: \.id) { subcategory in
                    ExerciseRow(
                        subcategory: subcategory,
                        isSelected: selectedSubcategories.contains(where: { $0.id == subcategory.id }),
                        workoutTypeColor: workoutTypeColor,
                        onTap: { onSubcategoryTap(subcategory) }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ExerciseRow: View, Equatable {
    let subcategory: WorkoutSubcategory
    let isSelected: Bool
    let workoutTypeColor: Color
    let onTap: () -> Void
    
    static func == (lhs: ExerciseRow, rhs: ExerciseRow) -> Bool {
        lhs.subcategory.id == rhs.subcategory.id && lhs.isSelected == rhs.isSelected
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(subcategory.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(workoutTypeColor)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(Color(.systemGray4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @Previewable @State var selectedSubcategories: [WorkoutSubcategory] = []
    @Previewable @State var selectedCategories: [WorkoutCategory] = []
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    
    CategoryAndSubcategorySelectionView(
        selectedCategories: $selectedCategories,
        selectedSubcategories: $selectedSubcategories,
        workoutType: .strength
    )
    .modelContainer(container)
} 
