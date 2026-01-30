import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var type: WorkoutType = .other
    @State private var date = Date()
    @State private var durationMinutes = 30.0
    @State private var distanceKilometers = 0.0
    @State private var notes = ""
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    @State private var showingCategoryPicker = false
    @State private var showingDuplicateAlert = false
    @State private var isSaving = false
    @State private var pendingWorkout: Workout?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) {
                    ForEach(WorkoutType.allCases) { workoutType in
                        Text(workoutType.rawValue).tag(workoutType)
                    }
                }
                DatePicker("Date", selection: $date)
                Stepper("Duration (min): \(Int(durationMinutes))", value: $durationMinutes, in: 0...600, step: 5)
                Stepper(
                    "Distance (km): \(distanceKilometers, format: .number.precision(.fractionLength(1)))",
                    value: $distanceKilometers,
                    in: 0...200,
                    step: 0.5
                )
                Section("Categories") {
                    Button("Select Categories") {
                        showingCategoryPicker = true
                    }
                    if !selectedCategories.isEmpty {
                        Text(selectedCategories.map(\.name).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                    if !selectedSubcategories.isEmpty {
                        Text(selectedSubcategories.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("New Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        guard !isSaving else { return }
                        isSaving = true
                        let workout = Workout(
                            type: type,
                            startDate: date,
                            duration: durationMinutes * 60,
                            distance: distanceKilometers > 0 ? distanceKilometers : nil,
                            notes: notes.isEmpty ? nil : notes,
                            categories: selectedCategories,
                            subcategories: selectedSubcategories
                        )
                        if isDuplicate(workout) {
                            pendingWorkout = workout
                            showingDuplicateAlert = true
                            isSaving = false
                            return
                        }
                        saveWorkout(workout)
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert("Duplicate Workout", isPresented: $showingDuplicateAlert) {
            Button("Save Anyway") {
                if let workout = pendingWorkout {
                    saveWorkout(workout)
                }
                pendingWorkout = nil
            }
            Button("Cancel", role: .cancel) {
                pendingWorkout = nil
            }
        } message: {
            Text("A similar workout already exists for this time.")
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategories,
                selectedSubcategories: $selectedSubcategories,
                workoutType: type
            )
        }
        .onChange(of: type) { _, _ in
            selectedCategories.removeAll()
            selectedSubcategories.removeAll()
        }
    }

    private func isDuplicate(_ workout: Workout) -> Bool {
        var countDescriptor = FetchDescriptor<Workout>()
        countDescriptor.fetchLimit = 2
        let existingCount = (try? modelContext.fetch(countDescriptor).count) ?? 0
        if existingCount < 2 { return false }
        let startOfDay = Calendar.current.startOfDay(for: workout.startDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { existing in
                existing.startDate >= startOfDay && existing.startDate < endOfDay
            }
        )
        let sameDayWorkouts = (try? modelContext.fetch(descriptor)) ?? []
        if sameDayWorkouts.isEmpty { return false }
        return sameDayWorkouts.contains { existing in
            guard existing.type == workout.type else { return false }
            if abs(existing.startDate.timeIntervalSince(workout.startDate)) > 60 { return false }
            if abs(existing.duration - workout.duration) > 60 { return false }
            if let existingDistance = existing.distance, let newDistance = workout.distance {
                if abs(existingDistance - newDistance) > 0.1 { return false }
            } else if (existing.distance != nil) || (workout.distance != nil) {
                return false
            }
            if (existing.notes ?? "") != (workout.notes ?? "") { return false }
            let existingCategoryIDs = Set((existing.categories ?? []).map(\.id))
            let newCategoryIDs = Set((workout.categories ?? []).map(\.id))
            if existingCategoryIDs != newCategoryIDs { return false }
            let existingSubcategoryIDs = Set((existing.subcategories ?? []).map(\.id))
            let newSubcategoryIDs = Set((workout.subcategories ?? []).map(\.id))
            if existingSubcategoryIDs != newSubcategoryIDs { return false }
            return true
        }
    }

    private func saveWorkout(_ workout: Workout) {
        modelContext.insert(workout)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            isSaving = false
        }
    }
}

#Preview {
    AddWorkoutView()
        .modelContainer(for: [Workout.self], inMemory: true)
}
