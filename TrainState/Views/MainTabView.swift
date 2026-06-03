import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var subcategories: [WorkoutSubcategory]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @AppStorage("quickLogSheetRequestToken") private var quickLogSheetRequestToken = ""
    @AppStorage("lastBackupReminderPromptTimeInterval") private var lastBackupReminderPromptTimeInterval: Double = 0
    @AppStorage("lastSuccessfulBackupTimeInterval") private var lastSuccessfulBackupTimeInterval: Double = 0
    @State private var selectedTab = "workouts"
    @State private var showBackupReminder = false
    @State private var backupReminderMessage = ""
    @State private var showBackupError = false
    @State private var backupErrorMessage = ""
    @State private var hasCheckedBackupReminder = false
    @State private var isEvaluatingBackupReminder = false

    private let oneWeek: TimeInterval = 7 * 24 * 60 * 60

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag("workouts")

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag("calendar")

            SavedRoutesView()
                .tabItem {
                    Label("Routes", systemImage: "map")
                }
                .tag("routes")

            if !purchaseManager.hasCompletedInitialPremiumCheck || purchaseManager.hasActiveSubscription {
                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar")
                    }
                    .tag("analytics")
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag("settings")
        }
        .onAppear {
            WorkoutWidgetSnapshotWriter.writeSnapshot(for: workouts)
            QuickExerciseLogStore.attachPendingLogs(
                to: workouts,
                availableSubcategories: subcategories,
                in: modelContext
            )
            guard !hasCheckedBackupReminder else { return }
            hasCheckedBackupReminder = true
            Task { await evaluateBackupReminderIfNeeded() }
        }
        .onChange(of: widgetSnapshotFingerprint) { _, _ in
            QuickExerciseLogStore.attachPendingLogs(
                to: workouts,
                availableSubcategories: subcategories,
                in: modelContext
            )
            WorkoutWidgetSnapshotWriter.writeSnapshot(for: workouts)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            QuickExerciseLogStore.attachPendingLogs(
                to: workouts,
                availableSubcategories: subcategories,
                in: modelContext
            )
            WorkoutWidgetSnapshotWriter.writeSnapshot(for: workouts)
            Task { await evaluateBackupReminderIfNeeded() }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .alert("Backup Reminder", isPresented: $showBackupReminder) {
            Button("Backup Now") {
                Task { await backupNowFromReminder() }
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text(backupReminderMessage)
        }
        .alert("Backup Failed", isPresented: $showBackupError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(backupErrorMessage)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "exercisepal" else { return }
        if url.host == "quick-log" {
            selectedTab = "workouts"
            quickLogSheetRequestToken = UUID().uuidString
        }
    }

    @MainActor
    private func evaluateBackupReminderIfNeeded() async {
        guard !isEvaluatingBackupReminder, !showBackupReminder else { return }
        isEvaluatingBackupReminder = true
        defer { isEvaluatingBackupReminder = false }

        let now = Date()
        if lastBackupReminderPromptTimeInterval > 0 {
            let lastPrompt = Date(timeIntervalSince1970: lastBackupReminderPromptTimeInterval)
            if now.timeIntervalSince(lastPrompt) < oneWeek {
                return
            }
        }

        do {
            let status = try await CloudKitManager.shared.checkCloudStatus()
            guard status == .available else { return }

            let backups = try await CloudKitManager.shared.fetchAvailableBackups()
            let latestBackupDate = backups.first?.date
            let shouldPrompt = latestBackupDate.map { now.timeIntervalSince($0) >= oneWeek } ?? true
            guard shouldPrompt else { return }

            if let latestBackupDate {
                backupReminderMessage = "Your last iCloud backup was on \(latestBackupDate.formatted(date: .abbreviated, time: .shortened)). Do you want to create a new backup now?"
            } else {
                backupReminderMessage = "You don't have an iCloud backup yet. Do you want to create one now?"
            }
            lastBackupReminderPromptTimeInterval = now.timeIntervalSince1970
            showBackupReminder = true
        } catch {
            if lastSuccessfulBackupTimeInterval <= 0 { return }
            let lastSuccessfulBackup = Date(timeIntervalSince1970: lastSuccessfulBackupTimeInterval)
            guard now.timeIntervalSince(lastSuccessfulBackup) >= oneWeek else { return }
            backupReminderMessage = "It's been over a week since your last backup. Do you want to create a new iCloud backup now?"
            lastBackupReminderPromptTimeInterval = now.timeIntervalSince1970
            showBackupReminder = true
        }
    }

    @MainActor
    private func backupNowFromReminder() async {
        do {
            try await CloudKitManager.shared.backupToCloud(context: modelContext)
            lastSuccessfulBackupTimeInterval = Date().timeIntervalSince1970
        } catch {
            backupErrorMessage = error.localizedDescription
            showBackupError = true
        }
    }

    private var widgetSnapshotFingerprint: String {
        workouts.map { workout in
            [
                workout.id.uuidString,
                String(workout.startDate.timeIntervalSince1970),
                String(workout.duration),
                String(workout.calories ?? 0),
                String(workout.distance ?? 0),
                workout.typeRawValue,
                String(workout.hkActivityTypeRaw ?? 0),
                String(workout.hkLocationTypeRaw ?? 0)
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutSubcategoryRating.self, UserSettings.self, WorkoutRoute.self, StrengthWorkoutTemplate.self, StrengthWorkoutTemplateExercise.self], inMemory: true)
}
