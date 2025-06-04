import SwiftUI
import SwiftData

// MARK: - Category Row View
private struct CategoryRowView: View {
    let category: WorkoutCategory
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: category.color) ?? .gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                Text("\(category.subcategories?.count ?? 0) subcategories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Category", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Subcategory Row View
private struct SubcategoryRowView: View {
    let subcategory: WorkoutSubcategory
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(subcategory.name)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(subcategory.workouts?.count ?? 0) workouts")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Subcategory", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 24)
    }
}

// MARK: - Category Section View
private struct CategorySectionView: View {
    let category: WorkoutCategory
    let onDeleteCategory: () -> Void
    let onDeleteSubcategory: (WorkoutSubcategory) -> Void
    let onAddSubcategory: () -> Void
    
    var body: some View {
        DisclosureGroup {
            if let subcategories = category.subcategories {
                ForEach(subcategories) { subcategory in
                    SubcategoryRowView(subcategory: subcategory) {
                        onDeleteSubcategory(subcategory)
                    }
                }
            }
            
            Button(action: onAddSubcategory) {
                Label("Add Subcategory", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.leading, 24)
        } label: {
            CategoryRowView(category: category) {
                onDeleteCategory()
            }
        }
    }
}

// MARK: - Workout Type Selector
private struct WorkoutTypeSelector: View {
    @Binding var selectedType: WorkoutType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    Button(action: { selectedType = type }) {
                        Text(type.rawValue.capitalized)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedType == type ? Color.blue : Color.secondary.opacity(0.1))
                            )
                            .foregroundColor(selectedType == type ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Main View
struct CategoriesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @State private var selectedWorkoutType: WorkoutType = .strength
    @State private var showingAddCategory = false
    @State private var showingAddSubcategory = false
    @State private var selectedCategory: WorkoutCategory?
    @State private var showingResetConfirmation = false
    
    private var filteredCategories: [WorkoutCategory] {
        categories.filter { $0.workoutType == selectedWorkoutType }
    }
    
    var body: some View {
        List {
            Section {
                WorkoutTypeSelector(selectedType: $selectedWorkoutType)
                    .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            Section {
                ForEach(filteredCategories) { category in
                    CategorySectionView(
                        category: category,
                        onDeleteCategory: { deleteCategory(category) },
                        onDeleteSubcategory: { deleteSubcategory($0) },
                        onAddSubcategory: {
                            selectedCategory = category
                            showingAddSubcategory = true
                        }
                    )
                }
                
                Button(action: { showingAddCategory = true }) {
                    Label("Add Category", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Categories")
                    Spacer()
                    Button("Reset to Default") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.blue)
                }
            } footer: {
                Text("Add, edit, or remove workout categories and their subcategories")
            }
        }
        .navigationTitle("Categories")
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                SimpleAddCategoryView(workoutType: selectedWorkoutType)
            }
        }
        .sheet(isPresented: $showingAddSubcategory) {
            if let category = selectedCategory {
                NavigationStack {
                    AddSubcategoryView(category: category)
                }
            }
        }
        .alert("Reset to Default Categories?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetToDefaultCategories()
            }
        } message: {
            Text("This will delete all existing categories and subcategories, and replace them with the default set. This action cannot be undone.")
        }
    }
    
    private func deleteCategory(_ category: WorkoutCategory) {
        withAnimation {
            modelContext.delete(category)
        }
    }
    
    private func deleteSubcategory(_ subcategory: WorkoutSubcategory) {
        withAnimation {
            modelContext.delete(subcategory)
        }
    }
    
    private func resetToDefaultCategories() {
        // Delete existing categories and subcategories
        for category in categories {
            modelContext.delete(category)
        }
        
        // Create default categories
        let defaultCategories = WorkoutCategory.createDefaultCategories()
        for category in defaultCategories {
            modelContext.insert(category)
        }
    }
}

// MARK: - Simple Add Category View
struct SimpleAddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let workoutType: WorkoutType
    @State private var name = ""
    @State private var color = Color.blue
    
    var body: some View {
        Form {
            TextField("Category Name", text: $name)
            ColorPicker("Color", selection: $color)
        }
        .navigationTitle("Add Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveCategory()
                }
                .disabled(name.isEmpty)
            }
        }
    }
    
    private func saveCategory() {
        let category = WorkoutCategory(
            name: name,
            color: color.toHex() ?? "#0000FF",
            workoutType: workoutType
        )
        modelContext.insert(category)
        dismiss()
    }
}

// MARK: - Add Subcategory View
struct AddSubcategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: WorkoutCategory
    @State private var name = ""
    
    var body: some View {
        Form {
            TextField("Subcategory Name", text: $name)
        }
        .navigationTitle("Add Subcategory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSubcategory()
                }
                .disabled(name.isEmpty)
            }
        }
    }
    
    private func saveSubcategory() {
        let subcategory = WorkoutSubcategory(name: name, category: category)
        modelContext.insert(subcategory)
        dismiss()
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

#Preview {
    NavigationStack {
        CategoriesManagementView()
    }
    .modelContainer(for: [WorkoutCategory.self], inMemory: true)
} 