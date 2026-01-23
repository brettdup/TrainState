import SwiftUI
import SwiftData
import MapKit

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingCategorySelection = false

    private var exercises: [WorkoutExercise] { (workout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex } }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                ScrollView {
                    VStack(spacing: 20) {
                        WorkoutDetailHeaderCard(workout: workout)
                            .padding(.top, 8)

                        WorkoutDetailCategoriesCard(workout: workout) {
                            showingCategorySelection = true
                        }

                        if !exercises.isEmpty {
                            WorkoutDetailExercisesCard(exercises: exercises)
                        }

                        if let notes = workout.notes, !notes.isEmpty {
                            WorkoutDetailNotesCard(notes: notes)
                        }

                        if let route = workout.route?.decodedRoute, !route.isEmpty {
                            RunningMapAndStatsCard(
                                route: route,
                                duration: workout.duration,
                                distance: workout.distance
                            )
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(workout.type.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionSheet(workout: workout)
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    private var durationFormatter: DateComponentsFormatter {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }

    private var distanceFormatter: MeasurementFormatter {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, WorkoutRoute.self, configurations: config)
    let sample = Workout(type: .running, startDate: Date(), duration: 1800, distance: 5000)
    return WorkoutDetailView(workout: sample)
        .modelContainer(container)
}
