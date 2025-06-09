import SwiftUI
import SwiftData

struct EditWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var selectedType: WorkoutType
    @State private var showValidationAlert = false
    
    init(workout: Workout) {
        self.workout = workout
        _selectedType = State(initialValue: workout.type)
    }
    
    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Edit Workout")
                        .font(.title2)
                        .bold()
                        .padding(.top, 16)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(.headline)
                        Picker("Type", selection: $selectedType) {
                            ForEach(WorkoutType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
                )
                .padding(.horizontal)
                Spacer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .fontWeight(.bold)
            }
        }
    }
    
    private func saveChanges() {
        workout.type = selectedType
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let workout = Workout(type: .strength, duration: 3600)
    
    return NavigationStack {
        EditWorkoutView(workout: workout)
    }
    .modelContainer(container)
} 