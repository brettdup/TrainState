import Foundation
import ActivityKit

struct WorkoutLiveAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var exerciseCount: Int
        var currentExercise: String
    }

    var workoutName: String
    var startedAt: Date
}

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()
    @available(iOS 16.1, *)
    private var activity: Activity<WorkoutLiveAttributes>?

    private init() {}

    func start(workoutName: String, startedAt: Date, exerciseCount: Int, currentExercise: String) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let activity {
            self.activity = nil
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        let attributes = WorkoutLiveAttributes(
            workoutName: workoutName,
            startedAt: startedAt
        )
        let content = WorkoutLiveAttributes.ContentState(
            elapsedSeconds: 0,
            exerciseCount: exerciseCount,
            currentExercise: currentExercise
        )

        do {
            let newActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: content, staleDate: nil),
                pushType: nil
            )
            activity = newActivity
        } catch {
            // Keep workout flow running even if live activity fails.
        }
    }

    func update(elapsedSeconds: Int, exerciseCount: Int, currentExercise: String) {
        guard #available(iOS 16.1, *) else { return }
        guard let activity else { return }
        let updatedState = WorkoutLiveAttributes.ContentState(
            elapsedSeconds: max(elapsedSeconds, 0),
            exerciseCount: max(exerciseCount, 0),
            currentExercise: currentExercise
        )
        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    func end() {
        guard #available(iOS 16.1, *) else { return }
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
