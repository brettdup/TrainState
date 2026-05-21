import AppIntents
import WidgetKit
import SwiftUI
import Foundation

private let quickLogAppGroupIdentifier = "group.brettduplessis.TrainState"
private let quickLogPendingLogsKey = "pendingQuickExerciseLogs"
private let quickLogWidgetKind = "QuickExerciseLogWidget"

struct QuickExerciseLogEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let lastExerciseName: String?
}

struct QuickExerciseLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickExerciseLogEntry {
        QuickExerciseLogEntry(date: .now, pendingCount: 1, lastExerciseName: "Bench Press")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickExerciseLogEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickExerciseLogEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(.now.addingTimeInterval(1_800))))
    }

    private func currentEntry() -> QuickExerciseLogEntry {
        let logs = QuickExerciseLogWidgetStore.pendingLogs()
        return QuickExerciseLogEntry(
            date: .now,
            pendingCount: logs.count,
            lastExerciseName: logs.sorted { $0.loggedAt > $1.loggedAt }.first?.exerciseName
        )
    }
}

struct QuickExerciseLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: quickLogWidgetKind, provider: QuickExerciseLogProvider()) { entry in
            QuickExerciseLogWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Quick Set")
        .description("Log a quick strength set now and attach it to today's workout later.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct QuickExerciseLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: QuickExerciseLogEntry
    private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 12) {
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.mint)
                Text("Quick Set")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: 0)
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount)")
                        .font(.caption2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(palette.primaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(palette.cardBackground, in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.lastExerciseName ?? "Log a set")
                    .font(family == .systemSmall ? .title3.weight(.heavy) : .title2.weight(.heavy))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Attaches to today's workout")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .lineLimit(1)
            }

            if family == .systemSmall {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Open")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(palette.cardBackground, in: Capsule())
            } else {
                HStack(spacing: 8) {
                    quickButton("Bench", .benchPress)
                    quickButton("Squat", .squat)
                    quickButton("Row", .row)
                }
            }
        }
        .padding(.horizontal, family == .systemSmall ? 16 : 18)
        .padding(.vertical, family == .systemSmall ? 22 : 18)
        .widgetURL(family == .systemSmall ? URL(string: "exercisepal://quick-log") : nil)
    }

    private func quickButton(_ title: String, _ exercise: QuickExerciseKind) -> some View {
        Button(intent: LogQuickExerciseIntent(exercise: exercise)) {
            Text(title)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.mint)
    }
}

struct LogQuickExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Quick Exercise"
    static var description = IntentDescription("Adds a pending exercise set that the app can attach to today's workout.")

    @Parameter(title: "Exercise")
    var exercise: QuickExerciseKind

    init() {
        exercise = .benchPress
    }

    init(exercise: QuickExerciseKind) {
        self.exercise = exercise
    }

    func perform() async throws -> some IntentResult {
        QuickExerciseLogWidgetStore.append(exercise.pendingLog)
        return .result()
    }
}

enum QuickExerciseKind: String, AppEnum {
    case benchPress
    case squat
    case row

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    static var caseDisplayRepresentations: [QuickExerciseKind: DisplayRepresentation] = [
        .benchPress: "Bench Press",
        .squat: "Squat",
        .row: "Row"
    ]

    fileprivate var pendingLog: QuickExercisePendingLog {
        switch self {
        case .benchPress:
            return QuickExercisePendingLog(exerciseName: "Bench Press", reps: 8, weight: nil)
        case .squat:
            return QuickExercisePendingLog(exerciseName: "Squat", reps: 5, weight: nil)
        case .row:
            return QuickExercisePendingLog(exerciseName: "Row", reps: 10, weight: nil)
        }
    }
}

private struct QuickExerciseLogWidgetStore {
    static func pendingLogs() -> [QuickExercisePendingLog] {
        guard let defaults = UserDefaults(suiteName: quickLogAppGroupIdentifier),
              let data = defaults.data(forKey: quickLogPendingLogsKey),
              let logs = try? JSONDecoder().decode([QuickExercisePendingLog].self, from: data) else {
            return []
        }
        return logs
    }

    static func append(_ log: QuickExercisePendingLog) {
        var logs = pendingLogs()
        logs.append(log)
        guard let defaults = UserDefaults(suiteName: quickLogAppGroupIdentifier),
              let data = try? JSONEncoder().encode(logs) else {
            return
        }
        defaults.set(data, forKey: quickLogPendingLogsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: quickLogWidgetKind)
    }
}

private struct QuickExercisePendingLog: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseName: String
    let loggedAt: Date
    let sets: Int
    let reps: Int
    let weight: Double?

    init(exerciseName: String, reps: Int, weight: Double?) {
        id = UUID()
        self.exerciseName = exerciseName
        loggedAt = .now
        sets = 1
        self.reps = reps
        self.weight = weight
    }
}

#Preview("Quick Set Small", as: .systemSmall) {
    QuickExerciseLogWidget()
} timeline: {
    QuickExerciseLogEntry(date: .now, pendingCount: 1, lastExerciseName: "Bench Press")
}

#Preview("Quick Set Medium", as: .systemMedium) {
    QuickExerciseLogWidget()
} timeline: {
    QuickExerciseLogEntry(date: .now, pendingCount: 2, lastExerciseName: "Squat")
}
