import SwiftUI
import SwiftData

struct DeveloperOptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    #if DEBUG
                    premiumOverrideCard
                    #endif
                    
                    dataCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Developer")
    }
    
    #if DEBUG
    private var premiumOverrideCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Testing")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Toggle(isOn: Binding(
                get: { purchaseManager.isDebugPremiumOverrideEnabled },
                set: { purchaseManager.setPremiumOverride($0) }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Premium Membership")
                            .font(.body)
                        Text("Override premium status for testing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.accentColor)

            Toggle(isOn: Binding(
                get: { purchaseManager.isDebugPremiumForceDisabled },
                set: { purchaseManager.setPremiumForceDisabled($0) }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.shield.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Force Premium Off")
                            .font(.body)
                        Text("Disable premium even if a real entitlement is active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.red)

            if purchaseManager.isDebugPremiumOverrideEnabled {
                Button(role: .destructive) {
                    purchaseManager.setPremiumOverride(false)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                        Text("Turn Premium Override Off")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            
            if purchaseManager.isDebugPremiumForceDisabled {
                HStack(spacing: 8) {
                    Image(systemName: "nosign")
                        .foregroundStyle(.red)
                    Text("Premium is currently forced OFF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if purchaseManager.hasActiveSubscription {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Premium is currently active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Note: Premium Override and Force Premium Off are mutually exclusive debug modes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
    #endif
    
    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                seedSampleWorkouts()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Seed Sample Workouts")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            NavigationLink {
                AppIconGenerator()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3.fill")
                    Text("Generate App Icon")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func seedSampleWorkouts() {
        // Ensure core seed data (categories, subcategories, templates, user settings) exists.
        DataInitializationManager.shared.initializeAppData(context: modelContext)

        let calendar = Calendar.current

        // Fetch categories & subcategories so seeded workouts are wired into the
        // current category model and show up correctly across all new views.
        let categoryDescriptor = FetchDescriptor<WorkoutCategory>()
        let subcategoryDescriptor = FetchDescriptor<WorkoutSubcategory>()

        let categories = (try? modelContext.fetch(categoryDescriptor)) ?? []
        let subcategories = (try? modelContext.fetch(subcategoryDescriptor)) ?? []

        func firstCategory(for type: WorkoutType) -> WorkoutCategory? {
            categories.first { $0.workoutType == type }
        }

        func firstSubcategory(
            for type: WorkoutType,
            matchingNameContains search: String? = nil
        ) -> WorkoutSubcategory? {
            let candidates = subcategories.filter { $0.category?.workoutType == type }
            guard !candidates.isEmpty else { return nil }

            if let search,
               let match = candidates.first(where: { $0.name.localizedCaseInsensitiveContains(search) }) {
                return match
            }
            return candidates.first
        }

        // Running sample (used by lists, insights, etc.)
        if let runningCategory = firstCategory(for: .running),
           let tempoSubcategory = firstSubcategory(for: .running, matchingNameContains: "tempo") {
            let date = calendar.date(byAdding: .day, value: 0, to: Date()) ?? Date()
            let workout = Workout(
                type: .running,
                startDate: date,
                duration: 45 * 60,
                distance: 6.2,
                categories: [runningCategory],
                subcategories: [tempoSubcategory]
            )
            modelContext.insert(workout)
        }

        // Strength sample (with exercises wired into subcategories so the new
        // exercise flows and insights have real data in the simulator).
        if let strengthCategory = firstCategory(for: .strength) {
            let strengthSubcategories = subcategories.filter { $0.category?.workoutType == .strength }
            let chest = strengthSubcategories.first { $0.name.localizedCaseInsensitiveContains("chest") }
            let legs = strengthSubcategories.first { $0.name.localizedCaseInsensitiveContains("leg") }

            let date = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let workout = Workout(
                type: .strength,
                startDate: date,
                duration: 50 * 60,
                categories: [strengthCategory],
                subcategories: [chest, legs].compactMap { $0 }
            )

            var exercises: [WorkoutExercise] = []

            if let chest {
                exercises.append(
                    WorkoutExercise(
                        name: "Bench Press",
                        sets: 4,
                        reps: 8,
                        weight: 80,
                        notes: "Simulator seed – chest focus",
                        orderIndex: 0,
                        workout: workout,
                        subcategory: chest
                    )
                )
            }

            if let legs {
                exercises.append(
                    WorkoutExercise(
                        name: "Back Squat",
                        sets: 3,
                        reps: 5,
                        weight: 100,
                        notes: "Simulator seed – legs focus",
                        orderIndex: 1,
                        workout: workout,
                        subcategory: legs
                    )
                )
            }

            workout.exercises = exercises
            modelContext.insert(workout)
            exercises.forEach { modelContext.insert($0) }
        }

        // Yoga sample.
        if let yogaCategory = firstCategory(for: .yoga),
           let flowSubcategory = firstSubcategory(for: .yoga, matchingNameContains: "flow") {
            let date = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            let workout = Workout(
                type: .yoga,
                startDate: date,
                duration: 30 * 60,
                categories: [yogaCategory],
                subcategories: [flowSubcategory]
            )
            modelContext.insert(workout)
        }

        // Cycling sample.
        if let cyclingCategory = firstCategory(for: .cycling),
           let roadSubcategory = firstSubcategory(for: .cycling, matchingNameContains: "road") {
            let date = calendar.date(byAdding: .day, value: -4, to: Date()) ?? Date()
            let workout = Workout(
                type: .cycling,
                startDate: date,
                duration: 60 * 60,
                distance: 18.5,
                categories: [cyclingCategory],
                subcategories: [roadSubcategory]
            )
            modelContext.insert(workout)
        }

        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        DeveloperOptionsView()
    }
    .modelContainer(for: [Workout.self], inMemory: true)
}
