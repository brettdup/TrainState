import RevenueCatUI
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue

    private var themeMode: AppThemeMode {
        get { AppThemeMode(rawValue: themeModeRaw) ?? .system }
        set { themeModeRaw = newValue.rawValue }
    }

    private var accentColor: AppAccentColor {
        get { AppAccentColor(rawValue: accentColorRaw) ?? .blue }
        set { accentColorRaw = newValue.rawValue }
    }
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
                    LazyVStack(spacing: 20) {
                        iCloudBackupCard
                        accountCard
                        preferencesCard
                        dataCard
                        premiumCard
                        developerCard
                        legalCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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

    private var iCloudBackupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iCloud Backup")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let statusMessage {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await createBackup() }
            } label: {
                HStack {
                    if isBackingUp {
                        ProgressView()
                        Text("Creating Backup...")
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("Backup to iCloud")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(isBackingUp)

            Button {
                Task { await loadBackups() }
            } label: {
                HStack {
                    if isLoadingBackups {
                        ProgressView()
                        Text("Loading Backups...")
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Backups")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingBackups)

            if !backups.isEmpty {
                ForEach(backups) { backup in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(backup.name)
                                .font(.body.weight(.medium))
                            Text("\(backup.workoutCount) workouts • \(backup.formattedDate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                Task { await restoreBackup(backup) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .disabled(isRestoring)
                            Button(role: .destructive) {
                                Task { await deleteBackup(backup) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Text("No backups found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(cloudStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            appearanceSection

            Toggle("Show Onboarding", isOn: $hasCompletedOnboarding.inverse)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                themeModePicker
                accentColorPicker
            }
        }
    }

    private var themeModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Theme", systemImage: "paintbrush.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Picker("Theme", selection: $themeModeRaw) {
                ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var accentColorPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Accent Color", systemImage: "paintpalette.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(AppAccentColor.allCases) { option in
                    accentColorOption(option)
                }
            }
        }
    }

    private func accentColorOption(_ option: AppAccentColor) -> some View {
        let isSelected = accentColor == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                accentColorRaw = option.rawValue
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 48, height: 48)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 3)
                            .frame(width: 48, height: 48)
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1)
                    }
                }

                Text(option.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? option.color.opacity(0.15) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            NavigationLink {
                CategoriesManagementView()
            } label: {
                SettingsRow(icon: "tag", title: "Manage Categories")
            }

            NavigationLink {
                SubcategoryLastLoggedView()
            } label: {
                SettingsRow(icon: "list.bullet", title: "Subcategory Activity")
            }

            Button(role: .destructive) {
                Task { await resetWorkouts() }
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Workouts")
                }
            }
            .buttonStyle(.plain)
            .disabled(isResettingWorkouts)
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showPaywall = true
                }
            } label: {
                SettingsRow(icon: "crown", title: "Premium")
            }
            .buttonStyle(.plain)

            NavigationLink {
                SubscriptionInfoView()
            } label: {
                SettingsRow(icon: "info.circle", title: "Subscription Info")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Developer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            NavigationLink {
                DeveloperOptionsView()
            } label: {
                SettingsRow(icon: "wrench.and.screwdriver", title: "Developer Options")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Legal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            NavigationLink {
                TermsOfUseView()
            } label: {
                SettingsRow(icon: "doc.text", title: "Terms of Use")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 32)
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

// MARK: - Settings Row
private struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
