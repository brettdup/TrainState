import SwiftUI
import SwiftData
import HealthKit

struct DeveloperOptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @State private var showingResetConfirmation = false
    @State private var showingOnboardingResetConfirmation = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let healthKitManager = HealthKitManager.shared
    
    var body: some View {
        Section {
            Button(role: .destructive, action: {
                showingResetConfirmation = true
            }) {
                HStack {
                    Label("Reset All Data", systemImage: "trash")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.red)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(role: .destructive, action: {
                showingOnboardingResetConfirmation = true
            }) {
                HStack {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.red)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                createSampleData()
            }) {
                HStack {
                    Label("Add Sample Data", systemImage: "plus.circle")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                Task {
                    do {
                        try await healthKitManager.createDefaultWorkout()
                    } catch {
                        print("Error creating default workout: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Label("Add Default Workout", systemImage: "figure.strengthtraining.traditional")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Developer Options")
        } footer: {
            Text("These options are for development and testing purposes")
        }
        .alert("Reset All Data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will delete all workouts, categories, and subcategories. This action cannot be undone.")
        }
        .alert("Reset Onboarding?", isPresented: $showingOnboardingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetOnboarding()
            }
        } message: {
            Text("This will reset the onboarding process. You'll need to go through it again when you restart the app.")
        }
    }
    
    private func resetAllData() {
        // Delete all workouts
        for workout in workouts {
            modelContext.delete(workout)
        }
        
        // Delete all subcategories
        for subcategory in subcategories {
            modelContext.delete(subcategory)
        }
        
        // Delete all categories
        for category in categories {
            modelContext.delete(category)
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully reset all data")
        } catch {
            print("Failed to reset data: \(error.localizedDescription)")
        }
    }
    
    private func resetOnboarding() {
        hasCompletedOnboarding = false
    }
    
    private func createSampleData() {
        // Create sample workouts for the last 14 days
        let calendar = Calendar.current
        let today = Date()
        
        // Sample workout types and their durations
        let sampleWorkouts: [(type: WorkoutType, duration: TimeInterval, calories: Double?)] = [
            (.strength, 3600, 450),  // 1 hour strength
            (.strength, 4500, 550),  // 1.25 hour strength
            (.strength, 5400, 650),  // 1.5 hour strength
            (.cardio, 1800, 300),    // 30 min cardio
            (.yoga, 2700, 200),      // 45 min yoga
            (.running, 2400, 350),   // 40 min running
            (.cycling, 3600, 400),   // 1 hour cycling
            (.swimming, 1800, 250),  // 30 min swimming
        ]
        
        // Get or create categories
        let pushCategory = categories.first { $0.name == "Push" } ?? WorkoutCategory(name: "Push", color: "#E53935", workoutType: .strength)
        let pullCategory = categories.first { $0.name == "Pull" } ?? WorkoutCategory(name: "Pull", color: "#1E88E5", workoutType: .strength)
        let legsCategory = categories.first { $0.name == "Legs" } ?? WorkoutCategory(name: "Legs", color: "#43A047", workoutType: .strength)
        
        // Create subcategories if they don't exist
        let pushSubcategories = ["Chest", "Shoulders", "Triceps"].map { name in
            subcategories.first { $0.name == name && $0.category?.id == pushCategory.id } ??
            WorkoutSubcategory(name: name, category: pushCategory)
        }
        
        let pullSubcategories = ["Back", "Biceps", "Rear Delts"].map { name in
            subcategories.first { $0.name == name && $0.category?.id == pullCategory.id } ??
            WorkoutSubcategory(name: name, category: pullCategory)
        }
        
        let legsSubcategories = ["Quads", "Hamstrings", "Calves"].map { name in
            subcategories.first { $0.name == name && $0.category?.id == legsCategory.id } ??
            WorkoutSubcategory(name: name, category: legsCategory)
        }
        
        // Insert categories and subcategories if they're new
        if !categories.contains(where: { $0.id == pushCategory.id }) {
            modelContext.insert(pushCategory)
        }
        if !categories.contains(where: { $0.id == pullCategory.id }) {
            modelContext.insert(pullCategory)
        }
        if !categories.contains(where: { $0.id == legsCategory.id }) {
            modelContext.insert(legsCategory)
        }
        
        for subcategory in pushSubcategories + pullSubcategories + legsSubcategories {
            if !subcategories.contains(where: { $0.id == subcategory.id }) {
                modelContext.insert(subcategory)
            }
        }
        
        // Create workouts for the last 14 days
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // Create 1-2 workouts per day
            let workoutsPerDay = Int.random(in: 1...2)
            for _ in 0..<workoutsPerDay {
                // For the first 9 days, prioritize strength workouts
                let sample: (type: WorkoutType, duration: TimeInterval, calories: Double?)
                if dayOffset < 9 {
                    // 70% chance of strength workout in first 9 days
                    if Double.random(in: 0...1) < 0.7 {
                        sample = sampleWorkouts.filter { $0.type == .strength }.randomElement()!
                    } else {
                        sample = sampleWorkouts.filter { $0.type != .strength }.randomElement()!
                    }
                } else {
                    sample = sampleWorkouts.randomElement()!
                }
                
                let workout = Workout(
                    type: sample.type,
                    startDate: date,
                    duration: sample.duration,
                    calories: sample.calories,
                    notes: "Sample workout"
                )
                
                // Add appropriate categories and subcategories based on workout type
                if sample.type == .strength {
                    // Randomly select 1-2 categories for strength workouts
                    let selectedCategories = [pushCategory, pullCategory, legsCategory].shuffled().prefix(Int.random(in: 1...2))
                    workout.categories = Array(selectedCategories)
                    
                    // Add corresponding subcategories
                    for category in selectedCategories {
                        let subs = category.name == "Push" ? pushSubcategories :
                                 category.name == "Pull" ? pullSubcategories :
                                 legsSubcategories
                        workout.subcategories.append(contentsOf: subs.shuffled().prefix(Int.random(in: 1...2)))
                    }
                }
                
                modelContext.insert(workout)
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully created sample data")
        } catch {
            print("Failed to create sample data: \(error.localizedDescription)")
        }
    }
}