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
                        let workout = Workout(
                            type: type,
                            startDate: date,
                            duration: durationMinutes * 60,
                            distance: distanceKilometers > 0 ? distanceKilometers : nil,
                            notes: notes.isEmpty ? nil : notes,
                            categories: selectedCategories,
                            subcategories: selectedSubcategories
                        )
                        modelContext.insert(workout)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
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
}

#Preview {
    AddWorkoutView()
        .modelContainer(for: [Workout.self], inMemory: true)
}
