import SwiftUI
import SwiftData
import HealthKit

struct OnboardingView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var showError = false
    @State private var errorMessage: String?
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to Exercise Tracker",
            description: "Your personal fitness companion that helps you track and analyze your workouts.",
            imageName: "figure.run",
            color: .blue
        ),
        OnboardingStep(
            title: "Import Your Workouts",
            description: "We'll import your existing workouts from Apple Health. This may take a few moments.",
            imageName: "arrow.down.circle",
            color: .green
        ),
        OnboardingStep(
            title: "Categorize Your Workouts",
            description: "Organize your workouts by type and track your progress over time.",
            imageName: "list.bullet.clipboard",
            color: .purple
        ),
        OnboardingStep(
            title: "Ready to Go!",
            description: "You're all set to start tracking your fitness journey.",
            imageName: "checkmark.circle",
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // Solid background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? steps[currentStep].color : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                
                // Content
                VStack(spacing: 20) {
                    Image(systemName: steps[currentStep].imageName)
                        .font(.system(size: 80))
                        .foregroundColor(steps[currentStep].color)
                        .padding()
                    
                    Text(steps[currentStep].title)
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if currentStep == 1 {
                        // Import progress view
                        VStack(spacing: 12) {
                            if isImporting {
                                ProgressView(value: importProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: steps[currentStep].color))
                                    .padding(.horizontal)
                                
                                Text("\(Int(importProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding()
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemGray5))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .foregroundColor(steps[currentStep].color)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button {
                            if currentStep == 1 {
                                importWorkouts()
                            } else {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentStep == 1 ? "Import Workouts" : "Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(steps[currentStep].color)
                                    .shadow(color: steps[currentStep].color.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        Button {
                            hasCompletedOnboarding = true
                        } label: {
                            HStack {
                                Text("Get Started")
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(steps[currentStep].color)
                                    .shadow(color: steps[currentStep].color.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            // Set up notification observer for import progress
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ImportProgressUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let progress = notification.userInfo?["progress"] as? Double {
                    importProgress = progress
                }
            }
        }
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
                try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
                
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

struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

#Preview {
    OnboardingView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

#Preview {
    OnboardingView()
        .modelContainer(for: UserSettings.self, inMemory: true)
} 
