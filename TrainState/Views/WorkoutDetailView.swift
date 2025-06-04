import SwiftUI
import SwiftData

// Import components
import TrainState

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout
    @State private var isEditing = false
    @State private var isEditingCategories = false
    @State private var isEditingSubcategories = false
    @State private var isEditingCategorySheet = false
    
    @Query private var categories: [WorkoutCategory]
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    headerCard
                    
                    // Stats Grid
                    statsGrid
                    
                    // Categories and Subcategories
                    categoriesCard
                    
                    // Notes
                    if let notes = workout.notes, !notes.isEmpty {
                        notesCard(notes)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EditWorkoutView(workout: workout)
            }
        }
        .sheet(isPresented: $isEditingCategorySheet) {
            NavigationStack {
                CategoryAndSubcategorySelectionView(
                    selectedCategories: $workout.categories,
                    selectedSubcategories: $workout.subcategories,
                    workoutType: workout.type
                )
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 0) {
            // Top section with icon and type
            HStack(spacing: 20) {
                // Icon with modern glass effect
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: iconForType(workout.type))
                        .font(.system(size: 30))
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.rawValue)
                        .font(.title2.weight(.bold))
                    
                    Text(friendlyDateTime(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            // Bottom section with date
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(formattedDate(workout.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            // Duration
            StatCard(
                icon: "clock.fill",
                value: formatDuration(workout.duration),
                color: .blue
            )
            
            // Calories
            if let calories = workout.calories {
                StatCard(
                    icon: "flame.fill",
                    value: "\(Int(calories)) cal",
                    color: .orange
                )
            }
            
            // Distance
            if let distance = workout.distance {
                StatCard(
                    icon: "figure.walk",
                    value: String(format: "%.1f km", distance / 1000),
                    color: .green
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Categories Card
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Categories & Subcategories")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    isEditingCategorySheet = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            
            if workout.categories.isEmpty && workout.subcategories.isEmpty {
                // Empty state
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    isEditingCategorySheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                        Text("Add Categories")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
            } else {
                // Categories
                if !workout.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Categories")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(workout.categories, id: \.id) { category in
                                CategoryChip(category: category)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                
                // Subcategories
                if !workout.subcategories.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Subcategories")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(workout.subcategories, id: \.id) { subcategory in
                                SubcategoryChip(subcategory: subcategory)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Notes Card
    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            
            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
        .padding(.horizontal)
    }

    // Helper for workout type icon
    private func iconForType(_ type: WorkoutType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.circle.fill"
        case .yoga: return "figure.mind.and.body"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "star.fill"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Relative Date Formatting Helpers
    private func friendlyDateTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today, \(formattedTime(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(formattedTime(date))"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let weekday = DateFormatter().weekdaySymbols[calendar.component(.weekday, from: date) - 1]
            return "\(weekday), \(formattedTime(date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// Helper View for consistent section styling in WorkoutDetailView
struct SectionView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let workout = Workout(type: .strength, duration: 3600)
    
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
} 

// New WrappingHStackLayout using Layout protocol
struct WrappingHStackLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
    
    private func computeRows(subviews: Subviews, proposalWidth: CGFloat) -> (rows: [[LayoutSubview]], subviewSizes: [CGSize]) {
        var rows: [[LayoutSubview]] = []
        var currentRow: [LayoutSubview] = []
        var currentRowWidth: CGFloat = 0
        // Ensure subviewSizes are computed based on the correct proposal, not always .unspecified for initial measurement if it causes issues.
        // However, .unspecified is standard for getting ideal size before constraining.
        let subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }

        for (index, subview) in subviews.enumerated() {
            let subviewSize = subviewSizes[index]
            // Check if adding this subview (plus spacing if not the first in row) exceeds proposal width
            if currentRowWidth + subviewSize.width + (currentRow.isEmpty ? 0 : horizontalSpacing) > proposalWidth && !currentRow.isEmpty {
                rows.append(currentRow) // Finish current row
                currentRow = []         // Start a new row
                currentRowWidth = 0     // Reset current row width
            }
            currentRow.append(subview)
            // Add subview width and spacing (if not the first item in this new/ongoing row)
            currentRowWidth += subviewSize.width + (currentRow.count > 1 ? horizontalSpacing : 0)
        }
        if !currentRow.isEmpty {
            rows.append(currentRow) // Add the last row
        }
        return (rows, subviewSizes)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        // Use proposed width, or infinity if not specified (Layouts often get a concrete width from parent)
        let effectiveProposalWidth = proposal.width ?? .infinity 
        let (rows, subviewSizes) = computeRows(subviews: subviews, proposalWidth: effectiveProposalWidth)

        let totalHeight = rows.enumerated().reduce(CGFloat.zero) { accumulatedHeight, rowData in
            let (rowIndex, rowViews) = rowData
            // Calculate height of the current row (max height of subviews in it)
            let rowHeight = rowViews.map { subview -> CGFloat in
                let subviewIndex = subviews.firstIndex(of: subview)!
                return subviewSizes[subviewIndex].height
            }.max() ?? 0
            // Add row height and vertical spacing (if not the first row)
            return accumulatedHeight + (rowIndex > 0 ? verticalSpacing : 0) + rowHeight
        }

        // Calculate max width used by any row, or use proposal if provided
        let maxWidth = rows.reduce(CGFloat.zero) { currentMaxWidth, rowViews in
            let rowWidth = rowViews.enumerated().reduce(CGFloat.zero) { accumulatedWidth, viewData in
                let (viewIndex, view) = viewData
                let subviewIndex = subviews.firstIndex(of: view)!
                return accumulatedWidth + (viewIndex > 0 ? horizontalSpacing : 0) + subviewSizes[subviewIndex].width
            }
            return max(currentMaxWidth, rowWidth)
        }
        
        // If a width was proposed, use it. Otherwise, use the calculated max width.
        return CGSize(width: proposal.width ?? maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        
        // Use bounds.width as the concrete width for placing subviews
        let (rows, subviewSizes) = computeRows(subviews: subviews, proposalWidth: bounds.width)
        var currentY = bounds.minY

        for (rowIndex, rowViews) in rows.enumerated() {
            var currentX = bounds.minX
            // Calculate the height of the current row for vertical positioning
            let rowHeight = rowViews.map { subview -> CGFloat in
                let subviewIndex = subviews.firstIndex(of: subview)!
                return subviewSizes[subviewIndex].height
            }.max() ?? 0
            
            // Add vertical spacing if not the first row
            if rowIndex > 0 {
                currentY += verticalSpacing
            }

            for (viewIndex, view) in rowViews.enumerated() {
                // Add horizontal spacing if not the first view in the row
                if viewIndex > 0 {
                    currentX += horizontalSpacing
                }
                let subviewIndex = subviews.firstIndex(of: view)!
                let currentSubviewSize = subviewSizes[subviewIndex]
                
                // Place the subview
                view.place(at: CGPoint(x: currentX, y: currentY),
                           anchor: .topLeading, // Align to top-left of its allocated space
                           proposal: ProposedViewSize(currentSubviewSize)) // Propose its ideal size
                
                currentX += currentSubviewSize.width // Move X for the next subview
            }
            currentY += rowHeight // Move Y for the next row
        }
    }
}
// END New WrappingHStackLayout

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategories: [WorkoutCategory]
    @State private var workoutType: WorkoutType
    
    @Query private var allCategories: [WorkoutCategory]
    
    var filteredCategories: [WorkoutCategory] {
        allCategories.filter { $0.workoutType == workoutType }
    }
    
    init(selectedCategories: Binding<[WorkoutCategory]>, workoutType: WorkoutType) {
        self._selectedCategories = selectedCategories
        self._workoutType = State(initialValue: workoutType)
    }
    
    var body: some View {
        let selectedCategoryIDs = Set(selectedCategories.map { $0.id })
        List {
            Section {
                Picker("Workout Type", selection: $workoutType) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section {
                if filteredCategories.isEmpty {
                    Text("No categories found for this workout type")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredCategories, id: \.id) { category in
                        Button(action: {
                            toggleCategory(category)
                        }) {
                            HStack {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 12, height: 12)
                                Text(category.name)
                                Spacer()
                                if selectedCategoryIDs.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("Select Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func toggleCategory(_ category: WorkoutCategory) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(category)
        }
    }
}

struct SubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedSubcategories: [WorkoutSubcategory]
    var selectedCategories: [WorkoutCategory]
    
    @Query private var allPersistedSubcategories: [WorkoutSubcategory]
    
    // Get subcategories for selected categories from persisted entities
    var subcategoryOptions: [String] {
        let selectedCategoryIDs = Set(selectedCategories.map { $0.id })
        return allPersistedSubcategories
            .filter { subcategory in
                guard let parentCategory = subcategory.category else { return false }
                return selectedCategoryIDs.contains(parentCategory.id)
            }
            .map { $0.name }
            .sorted()
            // To ensure unique names if somehow multiple persisted subcategories under the same parent have the same name
            // This would ideally be enforced at data entry, but good for robustness in display
            .reduce(into: [String]()) { result, name in 
                if !result.contains(name) {
                    result.append(name)
                }
            }
    }
    
    var body: some View {
        List {
            if subcategoryOptions.isEmpty {
                Text("Select a category first")
                    .foregroundColor(.secondary)
            } else {
                ForEach(subcategoryOptions, id: \.self) { sub in
                    Button(action: { toggleSubcategory(sub) }) {
                        HStack {
                            Text(sub)
                            Spacer()
                            if selectedSubcategories.contains(where: { $0.name == sub }) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Subcategories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private func toggleSubcategory(_ subName: String) {
        if let idx = selectedSubcategories.firstIndex(where: { $0.name == subName }) {
            selectedSubcategories.remove(at: idx)
        } else {
            // Check if subcategory already exists in SwiftData
            let fetchDescriptor = FetchDescriptor<WorkoutSubcategory>(
                predicate: #Predicate { $0.name == subName }
            )
            do {
                let existingSubcategories = try modelContext.fetch(fetchDescriptor)
                if let existingSubcategory = existingSubcategories.first {
                    selectedSubcategories.append(existingSubcategory)
                } else {
                    // If not, create and insert new one
                    let newSubcategory = WorkoutSubcategory(name: subName)
                    modelContext.insert(newSubcategory)
                    selectedSubcategories.append(newSubcategory)
                }
            } catch {
                print("Failed to fetch or create subcategory: \(error)")
                // Fallback to old behavior or handle error appropriately
                 let newSubcategory = WorkoutSubcategory(name: subName)
                 // modelContext.insert(newSubcategory) // Decide if insert should happen on error
                 selectedSubcategories.append(newSubcategory)
            }
        }
    }
}

struct CategoryAndSubcategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedCategories: [WorkoutCategory]
    @Binding var selectedSubcategories: [WorkoutSubcategory]
    @Query private var allWorkoutCategoriesFromDB: [WorkoutCategory]
    @Query private var allPersistedSubcategories: [WorkoutSubcategory]
    let workoutType: WorkoutType
    
    @State private var selectedTab: Int = 0
    @State private var animateSelection = false
    
    // Get categories for the specific workout type
    var filteredPrimaryCategories: [WorkoutCategory] {
        allWorkoutCategoriesFromDB.filter { $0.workoutType == workoutType }
    }
    
    // Subcategory options from persisted entities, mapped by parent category name
    var subcategoryOptions: [String: [WorkoutSubcategory]] {
        var options: [String: [WorkoutSubcategory]] = [:]
        for category in filteredPrimaryCategories {
            let subsForThisCategory = allPersistedSubcategories
                .filter { $0.category?.id == category.id }
                .sorted { $0.name < $1.name }
            if !subsForThisCategory.isEmpty {
                options[category.name] = subsForThisCategory
            }
        }
        return options
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom tab bar
                    HStack(spacing: 0) {
                        TabButton(
                            title: "Categories",
                            isSelected: selectedTab == 0,
                            action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = 0 } }
                        )
                        TabButton(
                            title: "Subcategories",
                            isSelected: selectedTab == 1,
                            action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = 1 } }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        // Categories Tab
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(filteredPrimaryCategories, id: \.id) { category in
                                    CategoryCard(
                                        category: category,
                                        isSelected: selectedCategories.contains(where: { $0.id == category.id }),
                                        onTap: { toggleCategory(category) }
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding()
                        }
                        .tag(0)
                        
                        // Subcategories Tab
                        ScrollView {
                            VStack(spacing: 24) {
                                ForEach(filteredPrimaryCategories, id: \.id) { category in
                                    if let subs = subcategoryOptions[category.name], !subs.isEmpty {
                                        SubcategoryGroup(
                                            category: category,
                                            subcategories: subs,
                                            selectedSubcategories: selectedSubcategories,
                                            onSubcategoryTap: { sub in
                                                toggleSubcategory(sub, for: category)
                                            }
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .padding()
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Select Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cleanupSubcategories()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func cleanupSubcategories() {
        selectedSubcategories.removeAll { sub in
            guard let cat = sub.category else { return true }
            return !selectedCategories.contains { $0.id == cat.id }
        }
    }
    
    private func toggleCategory(_ category: WorkoutCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let idx = selectedCategories.firstIndex(where: { $0.id == category.id }) {
                selectedCategories.remove(at: idx)
                selectedSubcategories.removeAll { sub in
                    sub.category?.id == category.id
                }
            } else {
                selectedCategories.append(category)
            }
        }
    }
    
    private func toggleSubcategory(_ sub: WorkoutSubcategory, for category: WorkoutCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if !selectedCategories.contains(where: { $0.id == category.id }) {
                return
            }
            
            if let idx = selectedSubcategories.firstIndex(where: { $0.id == sub.id }) {
                selectedSubcategories.remove(at: idx)
            } else {
                if sub.category?.id == category.id {
                    selectedSubcategories.append(sub)
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isSelected ? .blue : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    VStack {
                        Spacer()
                        if isSelected {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        }
                    }
                )
        }
    }
    
    @Namespace private var namespace
}

struct CategoryCard: View {
    let category: WorkoutCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color(hex: category.color) ?? .blue)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(.ultraThinMaterial, lineWidth: 2)
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    )
                
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct SubcategoryGroup: View {
    let category: WorkoutCategory
    let subcategories: [WorkoutSubcategory]
    let selectedSubcategories: [WorkoutSubcategory]
    let onSubcategoryTap: (WorkoutSubcategory) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack {
                Circle()
                    .fill(Color(hex: category.color) ?? .blue)
                    .frame(width: 12, height: 12)
                Text(category.name)
                    .font(.title3.weight(.semibold))
            }
            
            // Subcategories grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(subcategories, id: \.id) { sub in
                    SubcategoryCard(
                        subcategory: sub,
                        isSelected: selectedSubcategories.contains(where: { $0.id == sub.id }),
                        onTap: { onSubcategoryTap(sub) }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct SubcategoryCard: View {
    let subcategory: WorkoutSubcategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(subcategory.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// BlurView for sticky action bar
import UIKit
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let workout = Workout(type: .strength, duration: 3600)
    
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
} 
