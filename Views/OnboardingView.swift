import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var isImporting = false
    @State private var importProgress = 0.0
    @State private var errorMessage = ""
    @State private var showError = false

    private let healthKitManager = HealthKitManager()
    private let modelContext = PersistenceController.shared.container.viewContext

    var body: some View {
        // Implement the view content here
        Text("Onboarding View Content")
    }

    private func importWorkouts() {
        guard !isImporting else { return }
        
        isImporting = true
        importProgress = 0.0
        
        Task {
            do {
                // First, request authorization
                let success = try await healthKitManager.requestAuthorizationAsync()
                if !success {
                    errorMessage = "Please enable HealthKit access in Settings to import workouts"
                    showError = true
                    isImporting = false
                    return
                }
                
                // Then import workouts
                try await healthKitManager.importWorkoutsToCoreData(context: modelContext)
                
                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                    withAnimation {
                        currentStep += 1
                    }
                }
            } catch {
                // Skip showing any import errors and proceed to next step
                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                    withAnimation {
                        currentStep += 1
                    }
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 