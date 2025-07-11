import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    
    @State private var workoutType: WorkoutType = .strength
    @State private var startDate = Date()
    @State private var duration: TimeInterval = 3600 // 1 hour default
    @State private var calories: String = ""
    @State private var distance: String = ""
    @State private var notes: String = ""
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    @State private var showingCategorySelection = false
    @State private var isSaving = false
    
    // Duration picker state
    @State private var hours = 1
    @State private var minutes = 0
    
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
            ZStack {
                // Background
                BackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        workoutTypeSection
                        dateTimeSection
                        durationSection
                        metricsSection
                        categoriesSection
                        notesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for floating button
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                saveButton
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategoryAndSubcategorySelectionView(
                    selectedCategories: $selectedCategories,
                    selectedSubcategories: $selectedSubcategories,
                    workoutType: workoutType
                )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: workoutTypeIcon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(workoutTypeColor)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(workoutTypeColor.opacity(0.15))
                        .shadow(color: workoutTypeColor.opacity(0.3), radius: 12, y: 6)
                )
            
            VStack(spacing: 8) {
                Text("Create Your Workout")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("Log your exercise details and track your progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Workout Type Section
    private var workoutTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Type")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    WorkoutTypeCard(
                        type: type,
                        isSelected: workoutType == type,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                workoutType = type
                                selectedCategories.removeAll()
                                selectedSubcategories.removeAll()
                            }
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
        )
    }
    
    // MARK: - Date & Time Section
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date & Time")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            DatePicker(
                "Start Time",
                selection: $startDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
        )
    }
    
    // MARK: - Duration Section
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duration")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            HStack(spacing: 20) {
                // Hours picker
                VStack(spacing: 8) {
                    Text("Hours")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Picker("Hours", selection: $hours) {
                        ForEach(0...5, id: \.self) { hour in
                            Text("\(hour)")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                }
                
                // Minutes picker
                VStack(spacing: 8) {
                    Text("Minutes")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text("\(minute)")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
        )
        .onChange(of: hours) { _, newValue in
            updateDuration()
        }
        .onChange(of: minutes) { _, newValue in
            updateDuration()
        }
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metrics")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                // Calories
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calories Burned")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("Optional", text: $calories)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.regularMaterial)
                        )
                }
                
                // Distance (only for certain workout types)
                if [.running, .cycling, .swimming].contains(workoutType) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Distance (\(distanceUnit))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("Optional", text: $distance)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.regularMaterial)
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
        )
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories & Exercises")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: {
                    showingCategorySelection = true
                }) {
                    Image(systemName: selectedCategories.isEmpty && selectedSubcategories.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }
            
            if selectedCategories.isEmpty && selectedSubcategories.isEmpty {
                Button(action: {
                    showingCategorySelection = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.blue)
                        
                        Text("Add Categories")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                        
                        Text("Organize your workout")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        Color.blue.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    if !selectedCategories.isEmpty {
                        WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(selectedCategories, id: \.id) { category in
                                CategoryChip(category: category)
                            }
                        }
                    }
                    
                    if !selectedSubcategories.isEmpty {
                        WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(selectedSubcategories, id: \.id) { subcategory in
                                SubcategoryChip(subcategory: subcategory)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
        )
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            TextField("Add any notes about your workout...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                )
                .lineLimit(3...6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 12, y: 6)
        )
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveWorkout) {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Text(isSaving ? "Saving..." : "Save Workout")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [workoutTypeColor, workoutTypeColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: workoutTypeColor.opacity(0.4), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isSaving)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Properties
    private var workoutTypeIcon: String {
        switch workoutType {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.circle.fill"
        case .yoga: return "figure.mind.and.body"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    private var distanceUnit: String {
        switch workoutType {
        case .running: return "km"
        case .cycling: return "km"
        case .swimming: return "m"
        default: return "km"
        }
    }
    
    // MARK: - Helper Methods
    private func updateDuration() {
        duration = TimeInterval(hours * 3600 + minutes * 60)
    }
    
    private func saveWorkout() {
        guard !isSaving else { return }
        
        isSaving = true
        
        // Add a small delay to show the loading state (for better UX feedback)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            await MainActor.run {
                let caloriesValue = Double(calories.trimmingCharacters(in: .whitespacesAndNewlines))
                let distanceValue: Double?
                
                if let dist = Double(distance.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    // Convert to meters for storage
                    switch workoutType {
                    case .running, .cycling:
                        distanceValue = dist * 1000 // km to meters
                    case .swimming:
                        distanceValue = dist // already in meters
                    default:
                        distanceValue = nil
                    }
                } else {
                    distanceValue = nil
                }
                
                let newWorkout = Workout(
                    type: workoutType,
                    startDate: startDate,
                    duration: duration,
                    calories: caloriesValue,
                    distance: distanceValue,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // Debug: Print selected items before saving
                print("DEBUG: Saving workout with \(selectedCategories.count) categories and \(selectedSubcategories.count) subcategories")
                
                // Debug: Print all subcategories in context
                let allSubcategoriesDescriptor = FetchDescriptor<WorkoutSubcategory>()
                let allSubcategories = (try? modelContext.fetch(allSubcategoriesDescriptor)) ?? []
                print("DEBUG: All subcategories in context (\(allSubcategories.count)):")
                for sub in allSubcategories {
                    print("  - \(sub.name) (ID: \(sub.id))")
                }
                
                // Fetch categories and subcategories by ID to ensure they're in this context
                var validCategories: [WorkoutCategory] = []
                var validSubcategories: [WorkoutSubcategory] = []
                
                // Re-fetch categories by ID to ensure context consistency
                for selectedCategory in selectedCategories {
                    let id = selectedCategory.id
                    let descriptor = FetchDescriptor<WorkoutCategory>(
                        predicate: #Predicate { $0.id == id }
                    )
                    if let category = try? modelContext.fetch(descriptor).first {
                        validCategories.append(category)
                        print("DEBUG: Found category in context: \(category.name)")
                    } else {
                        print("DEBUG: Category \(selectedCategory.name) not found in context!")
                    }
                }
                
                // Re-fetch subcategories by ID to ensure context consistency
                for selectedSubcategory in selectedSubcategories {
                    let id = selectedSubcategory.id
                    let descriptor = FetchDescriptor<WorkoutSubcategory>(
                        predicate: #Predicate { $0.id == id }
                    )
                    if let subcategory = try? modelContext.fetch(descriptor).first {
                        validSubcategories.append(subcategory)
                        print("DEBUG: Found subcategory in context: \(subcategory.name)")
                    } else {
                        print("DEBUG: Subcategory \(selectedSubcategory.name) not found in context!")
                    }
                }
                
                // Set relationships with context-consistent objects
                newWorkout.categories = validCategories.isEmpty ? nil : validCategories
                newWorkout.subcategories = validSubcategories.isEmpty ? nil : validSubcategories
                
                // Insert workout into context
                modelContext.insert(newWorkout)
                
                // Debug: Check relationships after setting
                print("DEBUG: After setting relationships - Categories: \(newWorkout.categories?.count ?? 0), Subcategories: \(newWorkout.subcategories?.count ?? 0)")
                
                // Debug: Compare category vs subcategory handling
                print("DEBUG: Category details:")
                if let categories = newWorkout.categories {
                    for cat in categories {
                        print("  - Category: \(cat.name) (ID: \(cat.id), persistentModelID: \(cat.persistentModelID))")
                    }
                }
                
                print("DEBUG: Subcategory details:")
                if let subcategories = newWorkout.subcategories {
                    for sub in subcategories {
                        print("  - Subcategory: \(sub.name) (ID: \(sub.id), persistentModelID: \(sub.persistentModelID))")
                    }
                }
                
                do {
                    try modelContext.save()
                    
                    // Debug: Check relationships after saving
                    print("DEBUG: After saving - Categories: \(newWorkout.categories?.count ?? 0), Subcategories: \(newWorkout.subcategories?.count ?? 0)")
                    
                    // Debug: Compare category vs subcategory after saving
                    print("DEBUG: Categories after saving:")
                    if let categories = newWorkout.categories {
                        for cat in categories {
                            print("  - Category: \(cat.name) (ID: \(cat.id))")
                        }
                    } else {
                        print("  - No categories attached")
                    }
                    
                    // Debug: Print subcategory details after saving
                    print("DEBUG: Subcategories after saving:")
                    if let subcategories = newWorkout.subcategories {
                        for sub in subcategories {
                            print("  - Subcategory: \(sub.name) (ID: \(sub.id))")
                        }
                    } else {
                        print("  - No subcategories attached")
                    }
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    isSaving = false
                    dismiss()
                } catch {
                    print("Error saving workout: \(error)")
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct WorkoutTypeCard: View {
    let type: WorkoutType
    let isSelected: Bool
    let onTap: () -> Void
    
    private var typeColor: Color {
        switch type {
        case .strength: return .purple
        case .cardio: return .red
        case .yoga: return .mint
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .other: return .orange
        }
    }
    
    private var typeIcon: String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.circle.fill"
        case .yoga: return "figure.mind.and.body"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: typeIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : typeColor)
                
                Text(type.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? typeColor : Color(.systemGray6))
                    .shadow(
                        color: isSelected ? typeColor.opacity(0.3) : .primary.opacity(0.06),
                        radius: isSelected ? 12 : 6,
                        y: isSelected ? 6 : 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.3) : typeColor.opacity(0.2),
                        lineWidth: isSelected ? 1 : 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    
    return NavigationStack {
        AddWorkoutView()
    }
    .modelContainer(container)
} 
