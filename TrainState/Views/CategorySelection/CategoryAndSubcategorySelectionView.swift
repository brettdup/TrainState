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
    @State private var scrollOffset: CGFloat = 0
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue
    
    // Get categories for the specific workout type
    var filteredPrimaryCategories: [WorkoutCategory] {
        allWorkoutCategoriesFromDB.filter { $0.workoutType == workoutType }
    }
    
    // Subcategory options from persisted entities, mapped by parent category name
    var subcategoryOptions: [String: [WorkoutSubcategory]] {
        var options: [String: [WorkoutSubcategory]] = [:]
        for category in filteredPrimaryCategories {
            let subsForThisCategory = (category.subcategories ?? []).sorted { $0.name < $1.name }
            if !subsForThisCategory.isEmpty {
                options[category.name] = subsForThisCategory
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
        ZStack {
            // Modern background with subtle gradients
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Hero section with workout type
                heroSection
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Modern tab selector
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                
                // Add Category Form (shown when showingAddCategory is true)
                if showingAddCategory {
                    addCategoryForm
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Content
                GeometryReader { geometry in
                    TabView(selection: $selectedTab) {
                        // Categories Tab
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 20) {
                                ForEach(filteredPrimaryCategories, id: \.id) { category in
                                    ModernCategoryCard(
                                        category: category,
                                        isSelected: selectedCategories.contains(where: { $0.id == category.id }),
                                        workoutTypeColor: workoutTypeColor,
                                        onTap: { toggleCategory(category) }
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                                
                                // Add Category Card
                                AddCategoryCard(
                                    workoutTypeColor: workoutTypeColor,
                                    onTap: { 
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showingAddCategory.toggle()
                                        }
                                    }
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                        .tag(0)
                        
                        // Subcategories Tab
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 28) {
                                ForEach(filteredPrimaryCategories, id: \.id) { category in
                                    if let subs = subcategoryOptions[category.name], !subs.isEmpty {
                                        ModernSubcategoryGroup(
                                            category: category,
                                            subcategories: subs,
                                            selectedSubcategories: selectedSubcategories,
                                            workoutTypeColor: workoutTypeColor,
                                            onSubcategoryTap: { sub in
                                                toggleSubcategory(sub, for: category)
                                            }
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Select \(workoutType.rawValue) Categories")
                    .font(.headline.weight(.semibold))
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { 
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    dismiss() 
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    cleanupSubcategories()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        // Simple, performant background
        Color(.systemBackground)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 20) {
            // Main icon
            ZStack {
                // Animated background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                workoutTypeColor.opacity(0.2),
                                workoutTypeColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 16)
                    .scaleEffect(1.2)
                
                // Glass circle with icon
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: workoutTypeColor.opacity(0.2), radius: 12, y: 6)
                    .overlay(
                        Image(systemName: WorkoutTypeHelper.iconForType(workoutType))
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(workoutTypeColor)
                            .shadow(color: workoutTypeColor.opacity(0.3), radius: 6, y: 2)
                    )
            }
            
            VStack(spacing: 8) {
                Text("Organize Your \(workoutType.rawValue) Workout")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Choose categories and exercises to track your progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Categories",
                isSelected: selectedTab == 0,
                workoutTypeColor: workoutTypeColor,
                action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                        selectedTab = 0 
                    }
                }
            )
            
            TabButton(
                title: "Exercises",
                isSelected: selectedTab == 1,
                workoutTypeColor: workoutTypeColor,
                action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                        selectedTab = 1 
                    }
                }
            )
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.1), radius: 8, y: 4)
        )
    }
    
    // MARK: - Add Category Form
    private var addCategoryForm: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(workoutTypeColor)
                
                Text("Add New Category")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button("Cancel") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingAddCategory = false
                        newCategoryName = ""
                        newCategoryColor = workoutTypeColor
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 16) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter category name", text: $newCategoryName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .primary.opacity(0.04), radius: 4, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                
                // Color picker
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        ColorPicker("", selection: $newCategoryColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .primary.opacity(0.04), radius: 4, y: 2)
                            )
                    }
                    
                    Spacer()
                    
                    Button("Add Category") {
                        addNewCategory()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(workoutTypeColor)
                            .shadow(color: workoutTypeColor.opacity(0.3), radius: 8, y: 4)
                    )
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(workoutTypeColor.opacity(0.2), lineWidth: 1)
        )
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
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modelContext.insert(newCategory)
            try? modelContext.save()
            
            // Auto-select the new category
            selectedCategories.append(newCategory)
            
            // Reset form
            showingAddCategory = false
            newCategoryName = ""
            newCategoryColor = workoutTypeColor
        }
    }
    
    private func cleanupSubcategories() {
        selectedSubcategories.removeAll { sub in
            // Check if this subcategory belongs to any of the selected categories
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
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let idx = selectedCategories.firstIndex(where: { $0.id == category.id }) {
                selectedCategories.remove(at: idx)
                selectedSubcategories.removeAll { sub in
                    (category.subcategories ?? []).contains(where: { $0.id == sub.id })
                }
            } else {
                selectedCategories.append(category)
            }
        }
    }
    
    private func toggleSubcategory(_ sub: WorkoutSubcategory, for category: WorkoutCategory) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
}

// MARK: - Supporting Views

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let workoutTypeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? workoutTypeColor : Color.clear)
                        .shadow(color: isSelected ? workoutTypeColor.opacity(0.3) : .clear, radius: 8, y: 4)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct AddCategoryCard: View {
    let workoutTypeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Add icon
                ZStack {
                    Circle()
                        .fill(workoutTypeColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .shadow(color: workoutTypeColor.opacity(0.2), radius: 8, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(workoutTypeColor)
                }
                
                VStack(spacing: 6) {
                    Text("Add Category")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Create new category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(workoutTypeColor.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct ModernCategoryCard: View {
    let category: WorkoutCategory
    let isSelected: Bool
    let workoutTypeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Category icon with color
                ZStack {
                    Circle()
                        .fill(Color(hex: category.color) ?? workoutTypeColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: (Color(hex: category.color) ?? workoutTypeColor).opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(spacing: 6) {
                    Text(category.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(workoutTypeColor)
                            Text("Selected")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(workoutTypeColor)
                        }
                    } else {
                        Text("Tap to select")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected ? workoutTypeColor.opacity(0.6) : Color.primary.opacity(0.1), 
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct ModernSubcategoryGroup: View {
    let category: WorkoutCategory
    let subcategories: [WorkoutSubcategory]
    let selectedSubcategories: [WorkoutSubcategory]
    let workoutTypeColor: Color
    let onSubcategoryTap: (WorkoutSubcategory) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Category header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: category.color) ?? workoutTypeColor)
                    .frame(width: 20, height: 20)
                    .shadow(color: (Color(hex: category.color) ?? workoutTypeColor).opacity(0.3), radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("\(subcategories.count) exercises available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Subcategories in a flowing layout
            WrappingHStackLayout(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(subcategories, id: \.id) { subcategory in
                    ModernSubcategoryChip(
                        subcategory: subcategory,
                        isSelected: selectedSubcategories.contains(where: { $0.id == subcategory.id }),
                        workoutTypeColor: workoutTypeColor,
                        onTap: { onSubcategoryTap(subcategory) }
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.05), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ModernSubcategoryChip: View {
    let subcategory: WorkoutSubcategory
    let isSelected: Bool
    let workoutTypeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(subcategory.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? workoutTypeColor : Color(.systemBackground))
                    .shadow(color: isSelected ? workoutTypeColor.opacity(0.3) : .primary.opacity(0.06), radius: 6, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.primary.opacity(0.15), 
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    @Previewable @State var selectedSubcategories: [WorkoutSubcategory] = []
    @Previewable @State var selectedCategories: [WorkoutCategory] = []
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    
    NavigationStack {
        CategoryAndSubcategorySelectionView(
            selectedCategories: $selectedCategories,
            selectedSubcategories: $selectedSubcategories,
            workoutType: .strength
        )
    }
    .modelContainer(container)
} 
