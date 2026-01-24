import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @Query(sort: \Workout.startDate, order: .reverse) private var recentWorkouts: [Workout]
    
    // Workout data
    @State private var workoutType: WorkoutType = .strength
    @State private var startDate = Date()
    @State private var duration: TimeInterval = 3600 // 1 hour default
    
    @State private var distance: String = ""
    @State private var notes: String = ""
    
    // Exercises
    @State private var exercises: [ExerciseDraft] = []
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    
    // Duration picker state
    @State private var hours = 1
    @State private var minutes = 0
    
    // UI State
    @State private var isSaving = false
    @State private var currentStep: Int = 0
    private let totalSteps: Int = 6
    @State private var showingTemplates = false
    @State private var showingDuplicateWorkouts = false
    
    // MARK: - Helper Functions
    private func workoutTypeColor(for type: WorkoutType) -> Color {
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
    
    private func workoutTypeIcon(for type: WorkoutType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .yoga: return "figure.mind.and.body"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    var workoutTypeColor: Color {
        workoutTypeColor(for: workoutType)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                BackgroundView()
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    progressHeader
                    ScrollView {
                        if #available(iOS 26.0, *) {
                            GlassEffectContainer(spacing: 16) {
                                stepStack
                            }
                        } else {
                            stepStack
                        }
                    }
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if #available(iOS 26.0, *) {
                    navigationFooter
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 0))
                        .overlay(Divider(), alignment: .top)
                } else {
                    navigationFooter
                        .background(.ultraThinMaterial)
                        .overlay(Divider(), alignment: .top)
                }
            }
            .sheet(isPresented: $showingTemplates) {
                QuickTemplatesView(
                    workoutType: $workoutType,
                    hours: $hours,
                    minutes: $minutes,
                    distance: $distance,
                    notes: $notes
                )
            }
            .sheet(isPresented: $showingDuplicateWorkouts) {
                DuplicateWorkoutView(workouts: recentWorkouts) { workout in
                    duplicateWorkout(workout)
                    showingDuplicateWorkouts = false
                }
            }
            .onChange(of: currentStep) { _, _ in
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
        }
    }

    private var stepStack: some View {
        VStack(spacing: 24) {
            stepContent
        }
        .id(currentStep)
        .contentTransition(.opacity)
        .animation(.snappy(duration: 0.25, extraBounce: 0.05), value: currentStep)
        .padding(20)
        .padding(.bottom, 20)
    }
    // MARK: - Progress Header
    @ViewBuilder
    private var progressHeader: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(workoutTypeColor.opacity(0.12))
                    Image(systemName: stepIcon(for: currentStep))
                        .foregroundStyle(workoutTypeColor)
                        .font(.headline)
                }
                .frame(width: 32, height: 32)
                
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .foregroundStyle(index <= currentStep
                                          ? AnyShapeStyle(LinearGradient(colors: [workoutTypeColor.opacity(0.9), workoutTypeColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                          : AnyShapeStyle(Color(.systemGray4)))
                        .frame(height: 5)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            
            Text(stepTitle)
                .font(.title2.weight(.bold))
            Text(stepDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
                .padding(.horizontal, 12)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            VStack(spacing: 24) {
                quickActionsSection
                workoutTypeSection
            }
        case 1: dateTimeSection
        case 2: durationSection
        case 3: metricsSection
        case 4: exercisesSection
        case 5:
            VStack(spacing: 24) {
                categoriesSection
                notesSection
            }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let base = content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

        if #available(iOS 26.0, *) {
            base
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            base
                .background(.ultraThinMaterial, in: shape)
        }
    }

    private var durationSummary: String {
        let totalMinutes = max(0, hours * 60 + minutes)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    // MARK: - Navigation Footer
    private var navigationFooter: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentStep = max(currentStep - 1, 0)
                }
            } label: {
                let label = Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                if #available(iOS 26.0, *) {
                    label
                } else {
                    label
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .controlSize(.large)
            .buttonStyle(ScaleButtonStyle())
            .disabled(currentStep == 0)

            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = min(currentStep + 1, totalSteps - 1)
                    }
                } label: {
                    let label = HStack { Text("Next"); Image(systemName: "chevron.right") }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    if #available(iOS 26.0, *) {
                        label
                    } else {
                        label
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .controlSize(.large)
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button(action: saveWorkout) {
                    let label = Group {
                        if isSaving { ProgressView().tint(.white) }
                        else { Label("Save Workout", systemImage: "checkmark.circle.fill") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    if #available(iOS 26.0, *) {
                        label
                    } else {
                        label
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .controlSize(.large)
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16 + 8) // breathing room above home indicator
    }

    // MARK: - Step Metadata
    private var stepTitle: String {
        switch currentStep {
        case 0: return "Choose Workout Type"
        case 1: return "Which Day?"
        case 2: return "How Long Was It?"
        case 3: return "Add Metrics"
        case 4: return "Add Exercises"
        case 5: return "Organize & Notes"
        default: return ""
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 0: return "Select the workout you did"
        case 1: return "Pick the workout day"
        case 2: return "Set workout duration"
        case 3: return "Add optional distance"
        case 4: return "Track the exercises you performed"
        case 5: return "Categorize the workout and add notes"
        default: return ""
        }
    }
    
    private func stepIcon(for step: Int) -> String {
        switch step {
        case 0: return "figure.strengthtraining.traditional"
        case 1: return "calendar"
        case 2: return "clock"
        case 3: return "gauge"
        case 4: return "folder"
        default: return "circle"
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(workoutTypeColor)
                    Text("Quick Start")
                        .font(.headline)
                    Spacer()
                }
                Text("Start from a template or duplicate a recent workout.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        showingTemplates = true
                    } label: {
                        let label = Label("Templates", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 14)
                        if #available(iOS 26.0, *) {
                            label
                        } else {
                            label
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        showingDuplicateWorkouts = true
                    } label: {
                        let label = Label("Duplicate", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 14)
                        if #available(iOS 26.0, *) {
                            label
                        } else {
                            label
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(recentWorkouts.isEmpty)
                }

                if recentWorkouts.isEmpty {
                    Text("No recent workouts yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Workout Type Section
    private var workoutTypeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Workout Type")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        let isSelected = workoutType == type
                        Button(action: {
                            workoutType = type
                            selectedCategories.removeAll()
                            selectedSubcategories.removeAll()
                        }) {
                            let label = VStack(spacing: 8) {
                                Image(systemName: workoutTypeIcon(for: type))
                                    .font(.title2)
                                    .foregroundStyle(workoutTypeColor(for: type))
                                
                                Text(type.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            let tile = Group {
                                if #available(iOS 26.0, *) {
                                    label
                                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                                } else {
                                    label
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
                            }
                            tile
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Date Section
    private var dateTimeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Date")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                DatePicker("Date", selection: $startDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(workoutTypeColor)
            }
        }
    }
    

    
    // MARK: - Duration Section
    private var durationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Duration")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(durationSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hours")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Hours", selection: $hours) {
                            ForEach(0...5, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minutes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 80)
                    }
                }
                .onChange(of: hours) { _, _ in updateDuration() }
                .onChange(of: minutes) { _, _ in updateDuration() }
            }
        }
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Metrics (Optional)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if [.running, .cycling, .swimming].contains(workoutType) {
                    TextField("Distance (\(distanceUnit))", text: $distance)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text("Distance isn’t required for this workout type.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Exercises Section
    private var exercisesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Exercises (Optional)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Log sets, reps, and weight for the moves you did. Leave blank if this workout doesn’t use exercises.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    if exercises.isEmpty {
                        Button(action: addExerciseDraft) {
                            let label = Label("Add your first exercise", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 14)
                            if #available(iOS 26.0, *) {
                                label
                            } else {
                                label
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        ForEach($exercises) { $exercise in
                            ExerciseInputCard(
                                exercise: $exercise,
                                accentColor: workoutTypeColor,
                                onDelete: { removeExerciseDraft(id: exercise.id) }
                            )
                        }
                        
                        Button(action: addExerciseDraft) {
                            let label = Label("Add Exercise", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 14)
                            if #available(iOS 26.0, *) {
                                label
                            } else {
                                label
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Categories & Exercises")
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Performance-optimized category selection
                LazyVStack(spacing: 12) {
                    ForEach(filteredCategories, id: \.id) { category in
                        OptimizedCategoryRow(
                            category: category,
                            isSelected: selectedCategories.contains(where: { $0.id == category.id }),
                            selectedSubcategoryIds: Set(selectedSubcategories.map { $0.id }),
                            onToggleCategory: { toggleCategory(category) },
                            onToggleSubcategory: { sub in toggleSubcategory(sub) }
                        )
                    }
                }

                // Selected summary chips moved to bottom
                if !selectedCategories.isEmpty || !selectedSubcategories.isEmpty {
                    let content = VStack(alignment: .leading, spacing: 10) {
                        Text("Selected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if !selectedCategories.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                ForEach(selectedCategories, id: \.id) { category in
                                    Button(action: { toggleCategory(category) }) {
                                        CategoryChip(category: category)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if !selectedSubcategories.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                ForEach(selectedSubcategories, id: \.id) { subcategory in
                                    Button(action: { toggleSubcategory(subcategory) }) {
                                        SubcategoryChip(subcategory: subcategory)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Button(role: .destructive) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategories.removeAll()
                                selectedSubcategories.removeAll()
                            }
                        } label: {
                            Label("Clear Selections", systemImage: "xmark.circle")
                                .font(.footnote)
                        }
                    }
                    .padding(12)
                    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                    if #available(iOS 26.0, *) {
                        content
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    } else {
                        content
                            .background(.ultraThinMaterial, in: shape)
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Notes (Optional)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                TextField("Add notes about your workout...", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveWorkout) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                
                Text(isSaving ? "Saving..." : "Save Workout")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(workoutTypeColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }
    
    // MARK: - Helper Properties
    private var distanceUnit: String {
        switch workoutType {
        case .running, .cycling: return "km"
        case .swimming: return "m"
        default: return "km"
        }
    }
    
    private var filteredCategories: [WorkoutCategory] {
        // Dedupe by name and sort alphabetically for a cleaner selector
        let filtered = categories.filter { $0.workoutType == workoutType }
        var seen = Set<String>()
        var unique: [WorkoutCategory] = []
        for cat in filtered {
            let trimmedName = cat.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let key = "\(workoutType.rawValue.lowercased())::\(trimmedName.lowercased())"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(cat)
            }
        }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Helper Methods
    private func updateDuration() {
        duration = TimeInterval(hours * 3600 + minutes * 60)
    }
    
    private func toggleCategory(_ category: WorkoutCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
                // Deselect category and its subcategories
                selectedCategories.remove(at: index)
                selectedSubcategories.removeAll { $0.category?.id == category.id }
            } else {
                selectedCategories.append(category)
            }
        }
    }
    
    private func toggleSubcategory(_ subcategory: WorkoutSubcategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = selectedSubcategories.firstIndex(where: { $0.id == subcategory.id }) {
                selectedSubcategories.remove(at: index)
            } else {
                // Ensure parent category is selected
                if let parent = subcategory.category, !selectedCategories.contains(where: { $0.id == parent.id }) {
                    selectedCategories.append(parent)
                }
                selectedSubcategories.append(subcategory)
            }
        }
    }
    
    private func addExerciseDraft() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            exercises.append(ExerciseDraft())
        }
    }
    
    private func removeExerciseDraft(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            exercises.removeAll { $0.id == id }
        }
    }
    
    private func duplicateWorkout(_ workout: Workout) {
        workoutType = workout.type
        startDate = Date() // Use current time for duplicated workout
        duration = workout.duration
        
        
        if let workoutDistance = workout.distance {
            switch workout.type {
            case .running, .cycling:
                distance = String(format: "%.1f", workoutDistance / 1000) // Convert meters to km
            case .swimming:
                distance = String(format: "%.0f", workoutDistance) // Keep in meters
            default:
                distance = ""
            }
        } else {
            distance = ""
        }
        
        notes = workout.notes ?? ""
        selectedCategories = workout.categories ?? []
        selectedSubcategories = workout.subcategories ?? []
        
        // Update duration pickers
        let totalMinutes = Int(duration) / 60
        hours = totalMinutes / 60
        minutes = totalMinutes % 60
        

    }
    
    private func saveWorkout() {
        guard !isSaving else { return }
        
        isSaving = true
        
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            await MainActor.run {
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
                    calories: nil,
                    distance: distanceValue,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // Set relationships with context-consistent objects
                newWorkout.categories = selectedCategories.isEmpty ? nil : selectedCategories
                newWorkout.subcategories = selectedSubcategories.isEmpty ? nil : selectedSubcategories
                
                // Create and attach exercises
                let exerciseModels = sanitizedExercises(for: newWorkout)
                newWorkout.exercises = exerciseModels.isEmpty ? nil : exerciseModels
                exerciseModels.forEach { modelContext.insert($0) }
                
                // Insert workout into context
                modelContext.insert(newWorkout)
                
                do {
                    try modelContext.save()
                    
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
    
    private func sanitizedExercises(for workout: Workout) -> [WorkoutExercise] {
        exercises.enumerated().compactMap { index, draft in
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            
            let sets = Int(draft.sets.trimmingCharacters(in: .whitespacesAndNewlines))
            let reps = Int(draft.reps.trimmingCharacters(in: .whitespacesAndNewlines))
            let weight = Double(draft.weight.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines))
            let notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNotes = notes.isEmpty ? nil : notes
            
            return WorkoutExercise(
                name: trimmedName,
                sets: sets,
                reps: reps,
                weight: weight,
                notes: finalNotes,
                orderIndex: index,
                workout: workout
            )
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
            VStack(spacing: 16) {
                Image(systemName: typeIcon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : typeColor)
                
                Text(type.rawValue)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? typeColor : Color(.systemGray6))
                    .shadow(
                        color: isSelected ? typeColor.opacity(0.3) : .primary.opacity(0.06),
                        radius: isSelected ? 12 : 6,
                        y: isSelected ? 6 : 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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

// MARK: - Optimized Category Row
private struct OptimizedCategoryRow: View {
    let category: WorkoutCategory
    let isSelected: Bool
    let selectedSubcategoryIds: Set<UUID>
    let onToggleCategory: () -> Void
    let onToggleSubcategory: (WorkoutSubcategory) -> Void
    
    @State private var expanded: Bool = false
    
    private var categoryColor: Color {
        Color(hex: category.color) ?? .blue
    }
    
    private var selectedCount: Int {
        let subs = sortedSubcategories
        return subs.filter { selectedSubcategoryIds.contains($0.id) }.count
    }
    
    private var sortedSubcategories: [WorkoutSubcategory] {
        (category.subcategories ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    @ViewBuilder
    var body: some View {
        let content = DisclosureGroup(isExpanded: $expanded) {
            if !sortedSubcategories.isEmpty {
                ForEach(sortedSubcategories, id: \.id) { subcategory in
                    let isSelected = selectedSubcategoryIds.contains(subcategory.id)
                    Button {
                        onToggleSubcategory(subcategory)
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? categoryColor : .secondary)
                            Text(subcategory.name)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? categoryColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.headline)
                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggleCategory() }
        }
        .padding(12)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Exercise Input
private struct ExerciseDraft: Identifiable, Equatable {
    let id: UUID = UUID()
    var name: String = ""
    var sets: String = ""
    var reps: String = ""
    var weight: String = ""
    var notes: String = ""
}

private struct ExerciseInputCard: View {
    @Binding var exercise: ExerciseDraft
    let accentColor: Color
    let onDelete: () -> Void
    
    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(accentColor)
                        .font(.headline)
                }
                
                TextField("Exercise name", text: $exercise.name)
                    .textContentType(.none)
                    .submitLabel(.done)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                TextField("Sets", text: $exercise.sets)
                    .keyboardType(.numberPad)
                TextField("Reps", text: $exercise.reps)
                    .keyboardType(.numberPad)
                TextField("Weight (kg)", text: $exercise.weight)
                    .keyboardType(.decimalPad)
            }
            .textFieldStyle(.roundedBorder)
            
            TextField("Notes (optional)", text: $exercise.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Quick Templates View
struct QuickTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workoutType: WorkoutType
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var distance: String
    @Binding var notes: String
    
    private let templates = [
        WorkoutTemplate(name: "Quick Cardio", type: .cardio, hours: 0, minutes: 30, distance: "", notes: "Quick cardio session"),
        WorkoutTemplate(name: "Strength Training", type: .strength, hours: 1, minutes: 0, distance: "", notes: "Full body strength workout"),
        WorkoutTemplate(name: "Morning Run", type: .running, hours: 0, minutes: 45, distance: "5.0", notes: "Morning run"),
        WorkoutTemplate(name: "Yoga Session", type: .yoga, hours: 1, minutes: 0, distance: "", notes: "Relaxing yoga session"),
        WorkoutTemplate(name: "Cycling", type: .cycling, hours: 1, minutes: 30, distance: "20.0", notes: "Cycling workout"),
        WorkoutTemplate(name: "Swimming", type: .swimming, hours: 0, minutes: 30, distance: "1000", notes: "Swimming session")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    let grid = LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                        ForEach(templates, id: \.name) { template in
                            TemplateCard(template: template) {
                                applyTemplate(template)
                            }
                        }
                    }
                    if #available(iOS 26.0, *) {
                        GlassEffectContainer(spacing: 16) {
                            grid
                        }
                        .padding(20)
                    } else {
                        grid
                            .padding(20)
                    }
                }
            }
            .navigationTitle("Quick Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyTemplate(_ template: WorkoutTemplate) {
        workoutType = template.type
        hours = template.hours
        minutes = template.minutes
        distance = template.distance
        notes = template.notes
        dismiss()
    }
}

struct WorkoutTemplate {
    let name: String
    let type: WorkoutType
    let hours: Int
    let minutes: Int
    let distance: String
    let notes: String
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onTap: () -> Void
    
    private var typeColor: Color {
        switch template.type {
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
        switch template.type {
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
            let label = VStack(spacing: 12) {
                Image(systemName: typeIcon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(typeColor)
                
                Text(template.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text("\(template.hours)h \(template.minutes)m")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(16)
            if #available(iOS 26.0, *) {
                label
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            } else {
                label
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Duplicate Workout View
struct DuplicateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    let workouts: [Workout]
    let onSelect: (Workout) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                    .ignoresSafeArea()
                
                if workouts.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(.secondary)
                        
                        Text("No Workouts to Duplicate")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text("Add some workouts first to duplicate them")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        let list = LazyVStack(spacing: 12) {
                            ForEach(workouts.prefix(10), id: \.id) { workout in
                                DuplicateWorkoutRow(workout: workout) {
                                    onSelect(workout)
                                }
                            }
                        }
                        if #available(iOS 26.0, *) {
                            GlassEffectContainer(spacing: 12) {
                                list
                            }
                            .padding(20)
                        } else {
                            list
                                .padding(20)
                        }
                    }
                }
            }
            .navigationTitle("Duplicate Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DuplicateWorkoutRow: View {
    let workout: Workout
    let onTap: () -> Void
    
    private var workoutTypeColor: Color {
        switch workout.type {
        case .strength: return .purple
        case .cardio: return .red
        case .yoga: return .mint
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .other: return .orange
        }
    }
    
    private var workoutTypeIcon: String {
        switch workout.type {
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
            let label = HStack(spacing: 16) {
                Image(systemName: workoutTypeIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(workoutTypeColor)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(workoutTypeColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if workout.duration > 0 {
                        Text(durationFormatter.string(from: workout.duration) ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .padding(16)
            if #available(iOS 26.0, *) {
                label
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            } else {
                label
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
    
    private var durationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    
    NavigationStack {
        AddWorkoutView()
    }
    .modelContainer(container)
} 
