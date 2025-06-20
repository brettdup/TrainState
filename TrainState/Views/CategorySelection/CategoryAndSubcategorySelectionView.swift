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
    @State private var isAnimating = false
    @Namespace private var animation

    // Memoized/Cached Data
    @State private var cachedCategories: [WorkoutCategory] = []
    @State private var cachedSubcategoryOptions: [String: [WorkoutSubcategory]] = [:]

    private var selectedCategoryIDs: Set<UUID> { Set(selectedCategories.map { $0.id }) }
    private var selectedSubcategoryIDs: Set<UUID> { Set(selectedSubcategories.map { $0.id }) }

    private var workoutTypeColor: Color {
        WorkoutTypeHelper.colorForType(workoutType)
    }

    private var searchResults: [WorkoutCategory] {
        let allCategories = cachedCategories
        if searchText.isEmpty {
            return allCategories
        }
        return allCategories.filter { category in
            if category.name.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            if let subcategories = cachedSubcategoryOptions[category.name] {
                return subcategories.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                glassyHeader
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        if searchResults.isEmpty && !searchText.isEmpty {
                            noSearchResultsView
                        } else {
                            ForEach(searchResults) { category in
                                glassyCategoryCard(for: category)
                                    .padding(.horizontal, 8)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search categories or exercises")
            .onAppear(perform: initialSetup)
            .onChange(of: allWorkoutCategoriesFromDB) { _, _ in updateCachedData() }
            .onChange(of: workoutType) { _, _ in updateCachedData() }

            // Floating Add Button
            Button(action: { showingAddCategorySheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(workoutTypeColor)
                    .clipShape(Circle())
                    .shadow(color: workoutTypeColor.opacity(0.32), radius: 12, y: 4)
                    .overlay(
                        Circle().strokeBorder(Color.white, lineWidth: 2)
                    )
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
            .sheet(isPresented: $showingAddCategorySheet) {
                AddNewCategorySheet(
                    workoutType: workoutType,
                    onSave: { newCategory in
                        selectedCategories.append(newCategory)
                    }
                )
            }
        }
    }

    // MARK: - Glassy Header
    private var glassyHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .frame(height: 80)
                .padding(.horizontal, 8)
                .padding(.top, 8)
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(workoutTypeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                    Image(systemName: WorkoutTypeHelper.iconForType(workoutType))
                        .font(.system(size: 22, weight: .semibold))
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
                Button(action: handleDone) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundStyle(workoutTypeColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: workoutTypeColor.opacity(0.08), radius: 2, y: 1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Glassy Category Card
    private func glassyCategoryCard(for category: WorkoutCategory) -> some View {
        let isSelected = selectedCategoryIDs.contains(category.id)
        let cardColor = (Color(hex: category.color) ?? workoutTypeColor).opacity(isSelected ? 0.18 : 0.08)
        return VStack(spacing: 0) {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: isSelected ? .light : .medium)
                generator.impactOccurred()
                withAnimation(.easeInOut(duration: 0.18)) { toggleCategory(category) }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.color) ?? workoutTypeColor)
                            .frame(width: 28, height: 28)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .scaleEffect(isSelected ? 1.1 : 0.8)
                                .opacity(isSelected ? 1 : 0)
                                .animation(.easeInOut(duration: 0.18), value: isSelected)
                        }
                    }
                    Text(category.name)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isSelected ? 180 : 0))
                        .animation(.easeInOut(duration: 0.18), value: isSelected)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(cardColor)
                        .background(.ultraThinMaterial)
                        .animation(.easeInOut(duration: 0.18), value: isSelected)
                )
                .scaleEffect(isSelected ? 1.03 : 1.0)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? (Color(hex: category.color) ?? workoutTypeColor) : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            if isSelected {
                let subcategories = (cachedSubcategoryOptions[category.name] ?? []).filter {
                    searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                }
                if !subcategories.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(subcategories.indices, id: \ .self) { idx in
                            glassySubcategoryRow(subcategories[idx], for: category, accentColor: Color(hex: category.color) ?? workoutTypeColor)
                            if idx < subcategories.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    // MARK: - Glassy Subcategory Row
    private func glassySubcategoryRow(_ sub: WorkoutSubcategory, for category: WorkoutCategory, accentColor: Color) -> some View {
        let isSelected = selectedSubcategoryIDs.contains(sub.id)
        let rowColor = accentColor.opacity(isSelected ? 0.15 : 0.05)
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { toggleSubcategory(sub, for: category) }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? accentColor : Color(.systemGray5))
                        .frame(width: 22, height: 22)
                    Image(systemName: isSelected ? "checkmark" : "")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(isSelected ? 1.1 : 0.8)
                        .opacity(isSelected ? 1 : 0)
                        .animation(.easeInOut(duration: 0.18), value: isSelected)
                }
                Text(sub.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowColor)
                    .background(.ultraThinMaterial)
                    .animation(.easeInOut(duration: 0.18), value: isSelected)
            )
            .scaleEffect(isSelected ? 1.025 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Helper Methods
    private func initialSetup() {
        updateCachedData()
        if !isAnimating {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    self.isAnimating = true
                }
            }
        }
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

    private func handleDone() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        cleanupSubcategories()
        dismiss()
    }

    private func cleanupSubcategories() {
        selectedSubcategories.removeAll { sub in
            !selectedCategories.contains { category in
                (category.subcategories ?? []).contains { $0.id == sub.id }
            }
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
        guard selectedCategoryIDs.contains(category.id) else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        if let idx = selectedSubcategories.firstIndex(where: { $0.id == sub.id }) {
            selectedSubcategories.remove(at: idx)
        } else {
            selectedSubcategories.append(sub)
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
            // Handle error saving, e.g., show an alert
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
