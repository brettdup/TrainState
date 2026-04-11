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
                .activityBackgroundTint(Color.black.opacity(0.7))
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
                    elapsedTimerText(startedAt: context.attributes.startedAt, font: .headline)
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
                elapsedTimerText(startedAt: context.attributes.startedAt, font: .caption2)
            } minimal: {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.green)
            }
            .widgetURL(URL(string: "exercisepal://workout/live"))
            .keylineTint(.green)
        }
    }

    @ViewBuilder
    private func elapsedTimerText(startedAt: Date, font: Font) -> some View {
        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
            .font(font.monospacedDigit())
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

                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
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
