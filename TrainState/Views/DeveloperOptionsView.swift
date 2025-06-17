#if DEBUG
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
                Task {
                    do {
                        try await healthKitManager.createDefaultWorkout()
                    } catch {
                        print("Error creating default workout: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Label("Create HealthKit Workout", systemImage: "plus.circle")
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
}
#endif