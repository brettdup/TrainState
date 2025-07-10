import SwiftUI
import HealthKit
import SwiftData

struct HealthSettingsView: View {
    @State private var isHealthKitAuthorized = false
    @State private var isLoadingAuthStatus = true
    @State private var isImporting = false
    @State private var importProgress = 0.0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var exportEnabled = false
    @State private var importEnabled = true
    @State private var lastSyncDate: Date?
    
    @Environment(\.modelContext) private var modelContext
    
    private let healthKitManager = HealthKitManager()
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Status Card
                    statusCard
                        .padding(.horizontal)
                        .padding(.top, 12)
                    // Sync Card
                    if isHealthKitAuthorized {
                        syncCard
                            .padding(.horizontal)
                    }
                    // Import Card
                    if isHealthKitAuthorized {
                        importCard
                            .padding(.horizontal)
                    }
                    // About Card
                    aboutCard
                        .padding(.horizontal)
                    // Permissions Card
                    permissionsCard
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 600)
                .navigationTitle("Health Integration")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .onAppear {
            checkHealthKitAuthorizationStatus()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Cards
    private var statusCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isHealthKitAuthorized ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: isHealthKitAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isHealthKitAuthorized ? .green : .red)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(isHealthKitAuthorized ? "Connected to Apple Health" : "Not connected to Apple Health")
                        .font(.headline)
                    if isLoadingAuthStatus {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Checking authorization status...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            if !isHealthKitAuthorized && !isLoadingAuthStatus {
                Button(action: requestHealthKitAuthorization) {
                    Label("Connect to Apple Health", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .primary.opacity(0.06), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var syncCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
                Text("Sync Workouts with Health")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            HStack(spacing: 16) {
                Toggle(isOn: $importEnabled) {
                    Label("Import from Health", systemImage: "arrow.down.heart")
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                Toggle(isOn: $exportEnabled) {
                    Label("Export to Health", systemImage: "arrow.up.heart")
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 2)
            if let lastSync = lastSyncDate {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                    Text("Last Synced")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
                .font(.footnote)
            }
            Button(action: syncWithHealthKit) {
                if isImporting {
                    HStack {
                        ProgressView()
                        Text("Syncing...")
                    }
                } else {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(isImporting)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .blue.opacity(0.05), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.blue.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var importCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.green)
                Text("Import History")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            HStack(spacing: 12) {
                Button(action: importWorkouts) {
                    Label("Import Past Workouts", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonStyle(ScaleButtonStyle())
                .disabled(isImporting)
                Button(action: importUnimportedWorkouts) {
                    Label("Import All Unimported", systemImage: "arrow.down.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonStyle(ScaleButtonStyle())
                .disabled(isImporting)
            }
            if isImporting {
                VStack(spacing: 8) {
                    ProgressView(value: importProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("\(Int(importProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            NavigationLink(destination: HealthKitWorkoutsView()) {
                Label("Browse HealthKit Workouts", systemImage: "list.bullet.rectangle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .green.opacity(0.05), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.green.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.purple)
                Text("About Health Integration")
                    .font(.title3.weight(.semibold))
            }
            Text("TrainState can sync your workouts with Apple Health. This allows you to keep all your fitness data in one place.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .purple.opacity(0.05), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.purple.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.orange)
                Text("Permissions Management")
                    .font(.title3.weight(.semibold))
            }
            Button("Re-request HealthKit Permissions") {
                requestHealthKitAuthorization()
            }
            .buttonStyle(.bordered)
            .buttonStyle(ScaleButtonStyle())
            Button("Open Health App Settings") {
                openAppSettings()
            }
            .buttonStyle(.bordered)
            .buttonStyle(ScaleButtonStyle())
            Text("To fully revoke permissions, open the Settings app, go to Privacy & Security > Health > TrainState, and turn off all permissions.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .orange.opacity(0.05), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.orange.opacity(0.10), lineWidth: 1)
        )
    }
    
    private func checkHealthKitAuthorizationStatus() {
        isLoadingAuthStatus = true
        
        Task {
            do {
                let status = try await healthKitManager.checkAuthorizationStatusAsync()
                await MainActor.run {
                    isHealthKitAuthorized = status
                    isLoadingAuthStatus = false
                }
            } catch {
                await MainActor.run {
                    isHealthKitAuthorized = false
                    isLoadingAuthStatus = false
                    errorMessage = "Failed to check HealthKit authorization: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func requestHealthKitAuthorization() {
        Task {
            do {
                let success = try await healthKitManager.requestAuthorizationAsync()
                await MainActor.run {
                    isHealthKitAuthorized = success
                    if !success {
                        errorMessage = "HealthKit authorization was denied. You can enable it in Settings app."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to request HealthKit authorization: \(error.localizedDescription)"
                    showError = true
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
                try await healthKitManager.importWorkoutsToCoreData(context: modelContext)
                
                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to import workouts: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func importUnimportedWorkouts() {
        guard !isImporting else { return }

        isImporting = true
        importProgress = 0.0

        Task {
            do {
                try await healthKitManager.importWorkoutsToCoreData(context: modelContext)

                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to import workouts: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func mapHKWorkoutActivityTypeToWorkoutType(_ activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .yoga:
            return .yoga
        case .barre, .coreTraining, .dance, .flexibility, .highIntensityIntervalTraining, .jumpRope, .kickboxing, .pilates, .stairs, .stepTraining, .walking, .elliptical, .handCycling:
            return .cardio
        default:
            return .other
        }
    }
    
    private func syncWithHealthKit() {
        guard !isImporting else { return }
        
        isImporting = true
        
        Task {
            do {
                if importEnabled {
                    try await healthKitManager.importWorkoutsToCoreData(context: modelContext)
                }
                
                if exportEnabled {
                    // This would call a method to export workouts to HealthKit
                    // try await healthKitManager.exportWorkoutsToHealthKit(workouts)
                }
                
                await MainActor.run {
                    isImporting = false
                    lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to sync with HealthKit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // Helper to open app settings
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        HealthSettingsView()
    }
} 