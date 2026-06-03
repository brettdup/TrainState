import SwiftUI
import SwiftData
import HealthKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue
    @AppStorage("measurementSystem") private var measurementSystemRaw = MeasurementSystem.metric.rawValue
    @AppStorage("restTimerEnabled") private var restTimerEnabled = false
    @AppStorage("restTimerDurationSeconds") private var restTimerDurationSeconds = 90
    @Query private var userSettingsList: [UserSettings]

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
    @State private var backupToRestore: BackupInfo?
    @State private var backupToDelete: BackupInfo?
    @State private var showDeleteBackupAlert = false
    @State private var backupPreview: BackupPreview?
    @State private var isLoadingBackupPreview = false
    @State private var selectedAppIcon = AppIconOption.current

    var body: some View {
        NavigationStack {
            Form {
                iCloudBackupCard
                accountCard
                preferencesCard
                dataCard
                premiumCard
                developerCard
                legalCard
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                selectedAppIcon = AppIconOption.option(for: AppIconManager.shared.getCurrentAppIcon())
                if let settings = userSettingsList.first {
                    measurementSystemRaw = settings.measurementSystem.rawValue
                }
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
            .alert("Restore Backup", isPresented: Binding(
                get: { backupToRestore != nil },
                set: { if !$0 { backupToRestore = nil } }
            )) {
                Button("Restore") {
                    if let backup = backupToRestore {
                        backupToRestore = nil
                        Task { await restoreBackup(backup) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    backupToRestore = nil
                }
            } message: {
                if let backup = backupToRestore {
                    Text("This will replace all current workouts, categories, and subcategories with \"\(backup.name)\" (\(backup.workoutCount) workouts). This cannot be undone.")
                }
            }
            .alert("Delete Backup", isPresented: $showDeleteBackupAlert) {
                Button("Delete", role: .destructive) {
                    if let backup = backupToDelete {
                        showDeleteBackupAlert = false
                        backupToDelete = nil
                        Task { await deleteBackup(backup) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    showDeleteBackupAlert = false
                    backupToDelete = nil
                }
            } message: {
                if let backup = backupToDelete {
                    Text("Are you sure you want to delete \"\(backup.name)\"? This backup cannot be recovered.")
                }
            }
            .sheet(isPresented: $showPaywall) {
                CustomPaywallView()
            }
            .sheet(item: $backupPreview) { preview in
                BackupPreviewSheet(preview: preview)
            }
        }
    }

    private var iCloudBackupCard: some View {
        Section("iCloud Backup") {
            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }

            actionButton(
                title: isBackingUp ? "Creating Backup..." : "Backup to iCloud",
                systemImage: "icloud.and.arrow.up",
                tint: .accentColor,
                isLoading: isBackingUp
            ) {
                Task { await createBackup() }
            }
            .disabled(isBackingUp)

            actionButton(
                title: isLoadingBackups ? "Loading Backups..." : "Refresh Backups",
                systemImage: "arrow.clockwise",
                tint: .accentColor,
                isLoading: isLoadingBackups
            ) {
                Task { await loadBackups() }
            }
            .disabled(isLoadingBackups)

            if !backups.isEmpty {
                ForEach(backups) { backup in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(backup.name)
                                .font(.body.weight(.medium))
                            Text("\(backup.workoutCount) workouts • \(backup.categoryCount) categories • \(backup.subcategoryCount) subcategories • \(backup.formattedDate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button {
                                Task { await viewBackupData(backup) }
                            } label: {
                                Label("View Backup Data", systemImage: "eye")
                            }
                            .disabled(isLoadingBackupPreview)
                            Button {
                                backupToRestore = backup
                            } label: {
                                Label("Restore", systemImage: "arrow.clockwise")
                            }
                            .disabled(isRestoring)
                            Button(role: .destructive) {
                                backupToDelete = backup
                                showDeleteBackupAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else {
                Text("No backups found.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let label = HStack {
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)

        if #available(iOS 26, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(action: action) {
                label
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tint)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var accountCard: some View {
        Section("Account") {
            Text(cloudStatusText)
                .foregroundStyle(.secondary)
        }
    }

    private var preferencesCard: some View {
        Section("Preferences") {
            appearanceSection
            workoutLoggingSection
            Toggle("Show Onboarding", isOn: $hasCompletedOnboarding.inverse)
        }
        .onChange(of: measurementSystemRaw) { _, newValue in
            if let settings = userSettingsList.first,
               let system = MeasurementSystem(rawValue: newValue) {
                settings.measurementSystem = system
                try? modelContext.save()
            }
        }
    }

    private var workoutLoggingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Logging")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Units", selection: $measurementSystemRaw) {
                Text("Kilograms").tag(MeasurementSystem.metric.rawValue)
                Text("Pounds").tag(MeasurementSystem.imperial.rawValue)
            }
            .pickerStyle(.segmented)

            Toggle("Rest timer after sets", isOn: $restTimerEnabled)

            if restTimerEnabled {
                Stepper("Rest duration: \(restTimerDurationSeconds)s", value: $restTimerDurationSeconds, in: 30...300, step: 15)
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                themeModePicker
                accentColorPicker
                appIconPicker
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

    private var appIconPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("App Icon", systemImage: "app")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 12) {
                ForEach(AppIconOption.allCases) { option in
                    appIconOption(option)
                }
            }
        }
    }

    private func appIconOption(_ option: AppIconOption) -> some View {
        let isSelected = selectedAppIcon == option

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedAppIcon = option
            }
            AppIconManager.shared.setAppIcon(option)
        } label: {
            VStack(spacing: 8) {
                AppIconSwatch(option: option)
                    .frame(width: 52, height: 52)
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white, Color.accentColor)
                                .background(Circle().fill(Color.primary))
                                .offset(x: 5, y: 5)
                        }
                    }

                Text(option.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var dataCard: some View {
        Section("Data") {
            NavigationLink {
                CategoriesManagementView()
            } label: {
                SettingsRow(icon: "tag", title: "Manage Categories")
            }

            NavigationLink {
                SubcategoryLastLoggedView()
            } label: {
                SettingsRow(icon: "calendar.badge.clock", title: "Last Trained")
            }

            NavigationLink {
                StrengthTemplatesManagementView()
            } label: {
                SettingsRow(icon: "square.stack.3d.up", title: "Manage Strength Templates")
            }

            Button(role: .destructive) {
                Task { await resetWorkouts() }
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Workouts")
                }
            }
            .buttonStyle(.borderless)
            .disabled(isResettingWorkouts)
        }
    }

    private var premiumCard: some View {
        Section("Premium") {
            Button {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showPaywall = true
                }
            } label: {
                SettingsRow(icon: "crown", title: "Premium")
            }
            .buttonStyle(.borderless)

            NavigationLink {
                SubscriptionInfoView()
            } label: {
                SettingsRow(icon: "info.circle", title: "Subscription Info")
            }

            Button {
                openAppStoreReviewPage()
            } label: {
                SettingsRow(icon: "star.bubble", title: "Rate Exercise Pal")
            }
            .buttonStyle(.borderless)
        }
    }

    private var developerCard: some View {
        Section("Developer") {
            NavigationLink {
                DeveloperOptionsView()
            } label: {
                SettingsRow(icon: "wrench.and.screwdriver", title: "Developer Options")
            }
        }
    }

    private var legalCard: some View {
        Section("Legal") {
            NavigationLink {
                TermsOfUseView()
            } label: {
                SettingsRow(icon: "doc.text", title: "Terms of Use")
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
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSuccessfulBackupTimeInterval")
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

    private func viewBackupData(_ backup: BackupInfo) async {
        guard !isLoadingBackupPreview else { return }
        isLoadingBackupPreview = true
        statusMessage = "Loading backup data..."
        do {
            backupPreview = try await CloudKitManager.shared.fetchBackupPreview(backupInfo: backup)
            statusMessage = nil
        } catch {
            handleError(error)
        }
        isLoadingBackupPreview = false
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

    private func openAppStoreReviewPage() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id6747159475?action=write-review") else { return }
        openURL(url)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct AppIconSwatch: View {
    let option: AppIconOption

    var body: some View {
        Image(option.previewImageName)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}

private struct BackupPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: BackupPreview

    private var categoryByID: [UUID: WorkoutCategoryExport] {
        Dictionary(uniqueKeysWithValues: preview.categories.map { ($0.id, $0) })
    }

    private var subcategoryByID: [UUID: WorkoutSubcategoryExport] {
        Dictionary(uniqueKeysWithValues: preview.subcategories.map { ($0.id, $0) })
    }

    private func workoutDisplayName(_ workout: WorkoutExport) -> String {
        if let rawValue = workout.hkActivityTypeRaw,
           let activityType = HKWorkoutActivityType(rawValue: UInt(rawValue)) {
            let locationType = workout.hkLocationTypeRaw.flatMap(HKWorkoutSessionLocationType.init(rawValue:))
            return activityType.displayName(locationType: locationType)
        }
        return workout.type.rawValue
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Backup") {
                    LabeledContent("Name", value: preview.info.name)
                    LabeledContent("Date", value: preview.info.formattedDate)
                    LabeledContent("Device", value: preview.info.deviceName)
                    LabeledContent("Workouts", value: "\(preview.workouts.count)")
                    LabeledContent("Categories", value: "\(preview.categories.count)")
                    LabeledContent("Subcategories", value: "\(preview.subcategories.count)")
                }

                Section("Categories") {
                    if preview.categories.isEmpty {
                        Text("No categories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview.categories, id: \.id) { category in
                            Text(category.name)
                        }
                    }
                }

                Section("Subcategories") {
                    if preview.subcategories.isEmpty {
                        Text("No subcategories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview.subcategories, id: \.id) { subcategory in
                            HStack {
                                Text(subcategory.name)
                                Spacer()
                                if let categoryId = subcategory.categoryId, let category = categoryByID[categoryId] {
                                    Text(category.name)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Workouts") {
                    if preview.workouts.isEmpty {
                        Text("No workouts")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview.workouts, id: \.id) { workout in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workoutDisplayName(workout))
                                    .font(.headline)
                                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Duration: \(formattedDuration(workout.duration))")
                                    .font(.caption)
                                if let distance = workout.distance {
                                    Text(String(format: "Distance: %.2f km", distance))
                                        .font(.caption)
                                }
                                let categoryNames = (workout.categoryIds ?? []).compactMap { categoryByID[$0]?.name }
                                if !categoryNames.isEmpty {
                                    Text("Categories: \(categoryNames.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                let subcategoryNames = (workout.subcategoryIds ?? []).compactMap { subcategoryByID[$0]?.name }
                                if !subcategoryNames.isEmpty {
                                    Text("Subcategories: \(subcategoryNames.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let notes = workout.notes, !notes.isEmpty {
                                    Text("Notes: \(notes)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Backup Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
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
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}
