import RevenueCatUI
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var isLoadingBackups = false
    @State private var backups: [BackupInfo] = []
    @State private var statusMessage: String?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var cloudStatusText = "Checking iCloud..."
    @State private var showPaywall = false
    @State private var isResettingWorkouts = false

    var body: some View {
        NavigationStack {
            Form {
                Section("iCloud Backup") {
                    if let statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await createBackup() }
                    } label: {
                        if isBackingUp {
                            HStack {
                                ProgressView()
                                Text("Creating Backup...")
                            }
                        } else {
                            Text("Backup to iCloud")
                        }
                    }
                    .disabled(isBackingUp)

                    Button {
                        Task { await loadBackups() }
                    } label: {
                        if isLoadingBackups {
                            HStack {
                                ProgressView()
                                Text("Loading Backups...")
                            }
                        } else {
                            Text("Refresh Backups")
                        }
                    }
                    .disabled(isLoadingBackups)

                    if !backups.isEmpty {
                        ForEach(backups) { backup in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(backup.name)
                                Text("\(backup.workoutCount) workouts • \(backup.formattedDate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await deleteBackup(backup) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task { await restoreBackup(backup) }
                                } label: {
                                    Label("Restore", systemImage: "arrow.clockwise")
                                }
                                .tint(.blue)
                            }
                        }
                    } else {
                        Text("No backups found.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Account") {
                    Text(cloudStatusText)
                        .foregroundStyle(.secondary)
                }

                Section("Preferences") {
                    Toggle("Show Onboarding", isOn: $hasCompletedOnboarding.inverse)
                }

                Section("Data") {
                    NavigationLink("Manage Categories", destination: CategoriesManagementView())
                    NavigationLink("Subcategory Activity", destination: SubcategoryLastLoggedView())
                    Button("Reset All Workouts", role: .destructive) {
                        Task { await resetWorkouts() }
                    }
                    .disabled(isResettingWorkouts)
                }

                Section("Premium") {
                    Button("Premium") {
                        Task {
                            await purchaseManager.loadProducts()
                            await purchaseManager.updatePurchasedProducts()
                            showPaywall = true
                        }
                    }
                    NavigationLink("Subscription Info", destination: SubscriptionInfoView())
                }

                Section("Developer") {
                    NavigationLink("Developer Options", destination: DeveloperOptionsView())
                }

                Section("Legal") {
                    NavigationLink("Terms of Use", destination: TermsOfUseView())
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await loadBackups()
                    await loadCloudStatus()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPaywall) {
                if let offering = purchaseManager.offerings?.current {
                    PaywallView(offering: offering)
                } else {
                    VStack(spacing: 12) {
                        ProgressView("Loading paywall...")
                        Text("Premium")
                            .font(.title2.weight(.semibold))
                        Text("No paywall available.")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
    }

    @MainActor
    private func resetWorkouts() async {
        guard !isResettingWorkouts else { return }
        isResettingWorkouts = true
        do {
            try deleteAll(WorkoutRoute.self, batchSize: 25)
            try deleteAll(WorkoutExercise.self, batchSize: 50)
            try deleteAll(Workout.self, batchSize: 50)
        } catch {
            handleError(error)
        }
        isResettingWorkouts = false
    }

    @MainActor
    private func deleteAll<T: PersistentModel>(_ model: T.Type, batchSize: Int) throws {
        while true {
            var descriptor = FetchDescriptor<T>()
            descriptor.fetchLimit = batchSize
            let batch = try modelContext.fetch(descriptor)
            if batch.isEmpty { break }
            batch.forEach { modelContext.delete($0) }
            try modelContext.save()
        }
    }

    private func createBackup() async {
        guard !isBackingUp else { return }
        isBackingUp = true
        statusMessage = "Starting backup..."
        do {
            try await CloudKitManager.shared.backupToCloud(context: modelContext)
            statusMessage = "Backup complete."
            await loadBackups()
        } catch {
            handleError(error)
        }
        isBackingUp = false
    }

    private func loadBackups() async {
        guard !isLoadingBackups else { return }
        isLoadingBackups = true
        do {
            backups = try await CloudKitManager.shared.fetchAvailableBackups()
        } catch {
            handleError(error)
        }
        isLoadingBackups = false
    }

    private func restoreBackup(_ backup: BackupInfo) async {
        guard !isRestoring else { return }
        isRestoring = true
        statusMessage = "Restoring backup..."
        do {
            try await CloudKitManager.shared.restoreFromCloud(backupInfo: backup, context: modelContext)
            statusMessage = "Restore complete."
        } catch {
            handleError(error)
        }
        isRestoring = false
    }

    private func deleteBackup(_ backup: BackupInfo) async {
        do {
            _ = try await CloudKitManager.shared.deleteBackups([backup])
            backups.removeAll { $0.id == backup.id }
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
        statusMessage = nil
    }

    private func loadCloudStatus() async {
        do {
            let status = try await CloudKitManager.shared.checkCloudStatus()
            switch status {
            case .available:
                cloudStatusText = "iCloud: Available"
            case .noAccount:
                cloudStatusText = "iCloud: No account"
            case .restricted:
                cloudStatusText = "iCloud: Restricted"
            case .couldNotDetermine:
                cloudStatusText = "iCloud: Could not determine"
            @unknown default:
                cloudStatusText = "iCloud: Unknown"
            }
        } catch {
            cloudStatusText = "iCloud: Error"
        }
    }
}

private extension Binding where Value == Bool {
    var inverse: Binding<Bool> {
        Binding<Bool>(
            get: { !wrappedValue },
            set: { wrappedValue = !$0 }
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Workout.self], inMemory: true)
}
