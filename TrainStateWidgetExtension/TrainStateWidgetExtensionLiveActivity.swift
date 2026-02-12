import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var exerciseCount: Int
        var currentExercise: String
    }

    var workoutName: String
    var startedAt: Date
}

struct TrainStateWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .activityBackgroundTint(Color.black.opacity(0.15))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(formattedDuration(context.state.elapsedSeconds))
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.currentExercise)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Text("\(context.state.exerciseCount) exercises in progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(shortDuration(context.state.elapsedSeconds))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.green)
            }
            .widgetURL(URL(string: "trainstate://workout/live"))
            .keylineTint(.green)
        }
    }

    private func formattedDuration(_ elapsedSeconds: Int) -> String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func shortDuration(_ elapsedSeconds: Int) -> String {
        let minutes = elapsedSeconds / 60
        return "\(minutes)m"
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<WorkoutLiveAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                        Text("Live Workout")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(durationText)
                        .font(.headline.monospacedDigit())
                }

                Text(context.state.currentExercise)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text("\(context.state.exerciseCount) exercises logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var durationText: String {
        let elapsedSeconds = context.state.elapsedSeconds
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview("Live Activity - Bench", as: .content, using: WorkoutLiveAttributes(workoutName: "Strength Workout", startedAt: .now)) {
    TrainStateWidgetExtensionLiveActivity()
} contentStates: {
    WorkoutLiveAttributes.ContentState(elapsedSeconds: 1342, exerciseCount: 3, currentExercise: "Bench Press")
}

#Preview("Live Activity - Squats", as: .content, using: WorkoutLiveAttributes(workoutName: "Lower Body Session", startedAt: .now)) {
    TrainStateWidgetExtensionLiveActivity()
} contentStates: {
    WorkoutLiveAttributes.ContentState(elapsedSeconds: 2875, exerciseCount: 5, currentExercise: "Back Squat")
}

#Preview("Live Activity - Warmup", as: .content, using: WorkoutLiveAttributes(workoutName: "Push Day", startedAt: .now)) {
    TrainStateWidgetExtensionLiveActivity()
} contentStates: {
    WorkoutLiveAttributes.ContentState(elapsedSeconds: 420, exerciseCount: 1, currentExercise: "Incline Dumbbell Press")
}
