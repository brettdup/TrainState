import SwiftUI
import SwiftData
import MapKit

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
    @State private var showRouteSheet = false
    @State private var decodedRoute: [CLLocation] = []
    
    @Query private var categories: [WorkoutCategory]
    
    var body: some View {
        ZStack {
            ColorReflectiveBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerCard
                    infoCard
                    if workout.type == .running, let route = workout.route?.decodedRoute {
                        RunningMapAndStatsCard(route: route, duration: workout.duration, distance: workout.distance)
                    }
                    categoriesCard
                    if let notes = workout.notes, !notes.isEmpty {
                        notesCard(notes)
                    }
                }
                .padding(.vertical, 24)
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
        .sheet(isPresented: $showRouteSheet) {
            if workout.type == .running {
                RunningMapAndStatsCard(route: decodedRoute, duration: workout.duration, distance: workout.distance)
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    Image(systemName: iconForType(workout.type))
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(friendlyDateTime(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.secondary.opacity(0.08))
                .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(formattedDate(workout.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
    
    // MARK: - Info Card (consolidated workout info)
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: iconForType(workout.type))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(workout.type.rawValue)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            Divider().background(Color.secondary.opacity(0.08))
            HStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text(formatDuration(workout.duration))
                    .font(.body.weight(.medium))
                Spacer()
            }
            if let calories = workout.calories {
                HStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(calories)) cal")
                        .font(.body.weight(.medium))
                    Spacer()
                }
            }
            if let distance = workout.distance {
                HStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.green)
                    Text(String(format: "%.1f km", distance / 1000))
                        .font(.body.weight(.medium))
                    Spacer()
                }
            }
            HStack(spacing: 16) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(formattedDate(workout.startDate))
                    .font(.body.weight(.medium))
                Spacer()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
    
    // MARK: - Categories Card
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Categories & Subcategories")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !workout.categories.isEmpty || !workout.subcategories.isEmpty {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        isEditingCategorySheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.85), Color.blue.opacity(0.65)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                )
                                .shadow(color: .blue.opacity(0.18), radius: 8, y: 3)
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .blue.opacity(0.18), radius: 2, y: 1)
                        }
                        .contentShape(Circle())
                        .scaleEffect(isEditingCategorySheet ? 0.92 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditingCategorySheet)
                        .accessibilityLabel("Edit Categories")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)
                }
            }
            if workout.categories.isEmpty && workout.subcategories.isEmpty {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    isEditingCategorySheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                        Text("Add Categories")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(color: .blue.opacity(0.08), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            } else {
                if !workout.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
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
                if !workout.subcategories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
    
    // MARK: - Notes Card
    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notes")
                .font(.headline)
            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
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
            try? modelContext.save()
        } else {
            // Check if subcategory already exists in SwiftData
            let fetchDescriptor = FetchDescriptor<WorkoutSubcategory>(
                predicate: #Predicate { $0.name == subName }
            )
            do {
                let existingSubcategories = try modelContext.fetch(fetchDescriptor)
                if let existingSubcategory = existingSubcategories.first {
                    selectedSubcategories.append(existingSubcategory)
                    try? modelContext.save()
                } else {
                    // If not, create and insert new one
                    let newSubcategory = WorkoutSubcategory(name: subName)
                    modelContext.insert(newSubcategory)
                    selectedSubcategories.append(newSubcategory)
                    try? modelContext.save()
                }
            } catch {
                print("Failed to fetch or create subcategory: \(error)")
                // Fallback to old behavior or handle error appropriately
                 let newSubcategory = WorkoutSubcategory(name: subName)
                 // modelContext.insert(newSubcategory) // Decide if insert should happen on error
                 selectedSubcategories.append(newSubcategory)
                 try? modelContext.save()
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
        try? modelContext.save()
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

// MARK: - Running Map and Stats Card
struct RunningMapAndStatsCard: View {
    let route: [CLLocation]
    let duration: TimeInterval
    let distance: Double?

    // Use mock route if real route is empty
    private var displayRoute: [CLLocation] {
        route.isEmpty ? RunningMapAndStatsCard.mockRoute : route
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Route Map & Splits")
                .font(.headline)
            Text("Route points: \(displayRoute.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            RouteMapView(route: displayRoute)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 6)
            if let pace = averagePaceString {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.blue)
                    Text("Avg Pace: \(pace)")
                        .font(.body.weight(.medium))
                }
            }
            if !splits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splits")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(splits.enumerated()), id: \.0) { (i, split) in
                        Text("\(i+1) km: \(split)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }

    // Average pace as min/km
    private var averagePaceString: String? {
        guard let distance = distance, distance > 0 else { return nil }
        let pace = duration / distance * 1000 // seconds per km
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d min/km", minutes, seconds)
    }

    // Splits per km
    private var splits: [String] {
        guard let distance = distance, distance > 0 else { return [] }
        var splits: [String] = []
        var splitStartTime = displayRoute.first?.timestamp ?? Date()
        var accumulatedDistance: Double = 0
        for i in 1..<displayRoute.count {
            let d = displayRoute[i].distance(from: displayRoute[i-1])
            accumulatedDistance += d
            if accumulatedDistance >= 1000 {
                let splitEndTime = displayRoute[i].timestamp
                let splitDuration = splitEndTime.timeIntervalSince(splitStartTime)
                let min = Int(splitDuration) / 60
                let sec = Int(splitDuration) % 60
                splits.append(String(format: "%d:%02d", min, sec))
                splitStartTime = splitEndTime
                accumulatedDistance = 0
            }
        }
        return splits
    }

    // Mock route for demo/testing
    static var mockRoute: [CLLocation] {
        let base = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let points = (0..<20).map { i -> CLLocation in
            let lat = base.latitude + Double(i) * 0.001
            let lon = base.longitude + sin(Double(i) * .pi / 10) * 0.002
            return CLLocation(latitude: lat, longitude: lon)
        }
        // Add timestamps for splits
        let startTime = Date()
        return points.enumerated().map { (i, loc) in
            CLLocation(coordinate: loc.coordinate, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 2, timestamp: startTime.addingTimeInterval(Double(i) * 60))
        }
    }
}
