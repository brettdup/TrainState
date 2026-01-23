import SwiftUI
import SwiftData

// MARK: - Category Item View
private struct CategoryItemView: View {
    let category: WorkoutCategory
    let onDelete: () -> Void
    let onAddSubcategory: () -> Void
    @State private var isExpanded = false
    @State private var isPressed = false
    @Query private var allWorkouts: [Workout]
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }}) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color(hex: category.color) ?? .gray)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color(hex: category.color)?.opacity(0.3) ?? .clear, radius: 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                        Text("\(category.subcategories?.count ?? 0) subcategories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Subcategories List
            if isExpanded, let subcategories = category.subcategories, !subcategories.isEmpty {
                VStack(spacing: 0) {
                    ForEach(subcategories) { subcategory in
                        SubcategoryItemView(subcategory: subcategory, allWorkouts: allWorkouts)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Action Buttons
            if isExpanded {
                HStack(spacing: 20) {
                    Button(action: onAddSubcategory) {
                        Label("Add Subcategory", systemImage: "plus")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Divider()
                    
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Edit Subcategory View
private struct EditSubcategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let subcategory: WorkoutSubcategory
    @State private var name: String
    
    init(subcategory: WorkoutSubcategory) {
        self.subcategory = subcategory
        _name = State(initialValue: subcategory.name)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subcategory Name", text: $name)
                }
            }
            .navigationTitle("Edit Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        subcategory.name = name
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Subcategory Workouts View
private struct SubcategoryWorkoutsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var workouts: [Workout]
    let subcategory: WorkoutSubcategory

    init(subcategory: WorkoutSubcategory) {
        self.subcategory = subcategory
        let subcategoryId = subcategory.id
        let predicate = #Predicate<Workout> { workout in
            workout.subcategories?.contains { $0.id == subcategoryId } ?? false
        }
        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        _workouts = Query(descriptor)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "dumbbell.fill",
                        description: Text("No workouts have been logged for this subcategory yet.")
                    )
                } else {
                    ForEach(workouts) { workout in
                        SimpleWorkoutRowView(workout: workout)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("\(subcategory.name) Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Subcategory Item View
private struct SubcategoryItemView: View {
    let subcategory: WorkoutSubcategory
    let allWorkouts: [Workout]
    @State private var isPressed = false
    @State private var showingActions = false
    @State private var showingEditSheet = false
    @State private var showingWorkoutsSheet = false
    @Environment(\.modelContext) private var modelContext
    
    private var workoutCount: Int {
        allWorkouts.filter { workout in
            workout.subcategories?.contains(where: { $0.id == subcategory.id }) ?? false
        }.count
    }
    
    var body: some View {
        Button(action: { showingActions = true }) {
            HStack(spacing: 16) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(subcategory.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if workoutCount > 0 {
                        Text("\(workoutCount) workout\(workoutCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color(.secondarySystemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .confirmationDialog("Subcategory Actions", isPresented: $showingActions) {
            Button("Edit Name") {
                showingEditSheet = true
            }
            
            Button("View Workouts") {
                showingWorkoutsSheet = true
            }
            
            Button("Delete", role: .destructive) {
                deleteSubcategory()
            }
        } message: {
            Text("Choose an action for '\(subcategory.name)'")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSubcategoryView(subcategory: subcategory)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingWorkoutsSheet) {
            SubcategoryWorkoutsView(subcategory: subcategory)
                .presentationDetents([.large])
        }
    }
    
    private func deleteSubcategory() {
        // Remove subcategory from all workouts
        let workoutsToUpdate = allWorkouts.filter {
            $0.subcategories?.contains(where: { $0.id == subcategory.id }) ?? false
        }
        
        for workout in workoutsToUpdate {
            if var subcategories = workout.subcategories {
                subcategories.removeAll { $0.id == subcategory.id }
                workout.subcategories = subcategories
            }
        }
        
        // Delete the subcategory
        modelContext.delete(subcategory)
    }
}

// MARK: - Main View
struct CategoriesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [WorkoutCategory]
    @Query private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedWorkoutType: WorkoutType = .strength
    @State private var showingAddCategory = false
    @State private var selectedCategory: WorkoutCategory?
    @State private var showingResetConfirmation = false
    @State private var showingPremiumPaywall = false
    @State private var categoryToDelete: WorkoutCategory?
    @State private var showingDeleteWarning = false
    @State private var isRefreshing = false
    // --- Add for delete all ---
    @State private var showingDeleteAllConfirmation = false
    
    private var filteredCategories: [WorkoutCategory] {
        categories.filter { $0.workoutType == selectedWorkoutType }
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if !purchaseManager.hasActiveSubscription {
                // Present the full PremiumView instead of the custom paywall
                PremiumSheet(isPresented: $showingPremiumPaywall)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Workout Type Selector
                        workoutTypeSelector
                            .padding(.horizontal)
                        
                        // Categories List
                        LazyVStack(spacing: 16) {
                            ForEach(filteredCategories) { category in
                                CategoryItemView(
                                    category: category,
                                    onDelete: { deleteCategory(category) },
                                    onAddSubcategory: { selectedCategory = category }
                                )
                            }
                            
                            // Add Category Button
                            Button(action: { showingAddCategory = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add Category")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    isRefreshing = true
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    isRefreshing = false
                }
                .navigationTitle("Categories")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: { showingResetConfirmation = true }) {
                                Label("Reset to Default", systemImage: "arrow.counterclockwise")
                            }
                            // --- Add Delete All Categories option ---
                            Button(role: .destructive, action: { showingDeleteAllConfirmation = true }) {
                                Label("Delete All Categories", systemImage: "trash")
                            }
                            Button(action: { showingPremiumPaywall = true }) {
                                Label("Premium Features", systemImage: "star.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                SimpleAddCategoryView(workoutType: selectedWorkoutType)
                    .presentationDetents([.medium])
            }
        }
        .sheet(item: $selectedCategory) { category in
            NavigationStack {
                AddSubcategoryView(category: category)
                    .presentationDetents([.medium])
            }
        }
        
        .alert("Delete Category?", isPresented: $showingDeleteWarning) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteCategory()
            }
        } message: {
            if let category = categoryToDelete {
                Text("Deleting '\(category.name)' will remove it from all associated workouts. The workouts will remain but will no longer be categorized under '\(category.name)'. This action cannot be undone.")
            }
        }
        // --- Add Delete All Categories Alert ---
        .alert("Delete All Categories?", isPresented: $showingDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                deleteAllCategories()
            }
        } message: {
            Text("This will remove all categories and their subcategories for the selected workout type. Workouts will remain but will be uncategorized. This action cannot be undone.")
        }
        .alert("Reset to Default?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllCategoriesToDefault()
            }
        } message: {
            Text("This will delete ALL categories and subcategories, then recreate the full default set. Workouts will remain but will be uncategorized.")
        }
    }
    
    private var workoutTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedWorkoutType = type
                        }
                    }) {
                        Text(type.rawValue.capitalized)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedWorkoutType == type ? Color.accentColor : Color.secondary.opacity(0.1))
                            )
                            .foregroundColor(selectedWorkoutType == type ? .white : .primary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
    
    private func handlePurchase() {
        Task {
            if let product = purchaseManager.products.first(where: { $0.id == "Premium1Month" }) {
                do {
                    try await purchaseManager.purchase(product)
                    showingPremiumPaywall = false
                } catch {
                    print("Purchase failed:", error)
                }
            }
        }
    }
    
    private func deleteCategory(_ category: WorkoutCategory) {
        categoryToDelete = category
        showingDeleteWarning = true
    }
    
    private func confirmDeleteCategory() {
        guard let category = categoryToDelete else { return }
        withAnimation {
            modelContext.delete(category)
        }
        categoryToDelete = nil
    }
    
    private func deleteAllCategories() {
        withAnimation {
            for category in filteredCategories {
                modelContext.delete(category)
            }
        }
    }
    
    private func resetAllCategoriesToDefault() {
        // 1) Remove ALL category/subcategory relationships from workouts (avoid dangling references)
        for workout in workouts {
            workout.categories = nil
            workout.subcategories = nil
        }
        
        // 2) Delete ALL categories (subcategories cascade)
        withAnimation {
            for category in categories {
                modelContext.delete(category)
            }
        }
        
        // Save the wipe first so the store is in a clean state
        try? modelContext.save()
        
        // 3) Recreate defaults for ALL workout types (no duplicates by type+name)
        var createdByKey: [String: WorkoutCategory] = [:]
        
        for type in WorkoutType.allCases {
            for t in defaultCategoryTemplates(for: type) {
                let trimmedName = t.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { continue }
                
                let key = "\(type.rawValue.lowercased())::\(trimmedName.lowercased())"
                let category: WorkoutCategory
                if let existing = createdByKey[key] {
                    category = existing
                } else {
                    let new = WorkoutCategory(
                        name: trimmedName,
                        color: t.color.toHex() ?? "#0000FF",
                        workoutType: type
                    )
                    modelContext.insert(new)
                    createdByKey[key] = new
                    category = new
                }
                
                // Add default subcategories/exercises, de-duped by name within category
                var subSeen = Set<String>()
                for subName in t.subcategories {
                    let trimmedSub = subName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedSub.isEmpty else { continue }
                    let subKey = trimmedSub.lowercased()
                    guard subSeen.insert(subKey).inserted else { continue }
                    
                    let sub = WorkoutSubcategory(name: trimmedSub)
                    sub.category = category
                    modelContext.insert(sub)
                }
            }
        }
        
        try? modelContext.save()
    }
    
    private func defaultCategoryTemplates(for type: WorkoutType) -> [(name: String, color: Color, subcategories: [String])] {
        switch type {
        case .strength:
            // Use the existing CategoryManager “defaults”
            let base = CategoryManager.shared.categories
            return [
                (name: "Push", color: .red, subcategories: base["Push"] ?? []),
                (name: "Pull", color: .blue, subcategories: base["Pull"] ?? []),
                (name: "Legs", color: .green, subcategories: base["Legs"] ?? [])
            ]
        case .running:
            return [
                (name: "Easy", color: .blue, subcategories: ["Warmup", "Cooldown"]),
                (name: "Tempo", color: .orange, subcategories: ["Intervals"]),
                (name: "Long Run", color: .purple, subcategories: [])
            ]
        case .cardio:
            return [
                (name: "Zone 2", color: .green, subcategories: []),
                (name: "Intervals", color: .orange, subcategories: []),
                (name: "Recovery", color: .mint, subcategories: [])
            ]
        case .cycling:
            return [
                (name: "Endurance", color: .green, subcategories: []),
                (name: "Intervals", color: .orange, subcategories: []),
                (name: "Recovery", color: .mint, subcategories: [])
            ]
        case .swimming:
            return [
                (name: "Technique", color: .cyan, subcategories: []),
                (name: "Endurance", color: .green, subcategories: []),
                (name: "Speed", color: .orange, subcategories: [])
            ]
        case .yoga:
            return [
                (name: "Flow", color: .mint, subcategories: []),
                (name: "Mobility", color: .green, subcategories: []),
                (name: "Recovery", color: .blue, subcategories: [])
            ]
        case .other:
            return [
                (name: "General", color: .gray, subcategories: [])
            ]
        }
    }
}

// MARK: - Simple Add Category View
struct SimpleAddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCategories: [WorkoutCategory]
    
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let normalized = trimmed.lowercased()
        if let existing = allCategories.first(where: { cat in
            cat.workoutType == workoutType &&
            cat.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }) {
            // Category already exists (no duplicates)
            dismiss()
            return
        }
        
        let category = WorkoutCategory(
            name: trimmed,
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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Category Info Card
                    categoryInfoCard
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // Input Card
                    inputCard
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 600)
            }
        }
        .navigationTitle("Add Subcategory")
        .navigationBarTitleDisplayMode(.large)
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
    
    private var categoryInfoCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color(hex: category.color) ?? .blue)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adding subcategory to")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(category.name)
                        .font(.title2.weight(.semibold))
                }
                Spacer()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var inputCard: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.green)
                Text("Subcategory Details")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Enter subcategory name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .primary.opacity(0.04), radius: 8, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            
            Button(action: saveSubcategory) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Add Subcategory")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .buttonStyle(ScaleButtonStyle())
            .disabled(name.isEmpty)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .green.opacity(0.05), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.green.opacity(0.10), lineWidth: 1)
        )
    }
    
    private func saveSubcategory() {
        let subcategory = WorkoutSubcategory(name: name)
        if category.subcategories == nil {
            category.subcategories = []
        }
        category.subcategories?.append(subcategory)
        modelContext.insert(subcategory)
        dismiss()
    }
}

// MARK: - Premium Paywall View
struct PremiumSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationStack {
            PremiumView()
        }
        .presentationDetents([.large])
        .onDisappear { isPresented = false }
    }
}

// MARK: - Simple Workout Row View
struct SimpleWorkoutRowView: View {
    let workout: Workout
    
    private var iconName: String {
        switch workout.type {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    private var iconColor: Color {
        switch workout.type {
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .yoga: return .purple
        case .strength: return .orange
        case .cardio: return .red
        case .other: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.type.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(formatDate(workout.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        CategoriesManagementView()
    }
    .modelContainer(for: [WorkoutCategory.self], inMemory: true)
}
