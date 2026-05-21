import WidgetKit
import SwiftUI

@main
struct TrainStateWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        WeeklyWorkoutSummaryWidget()
        QuickExerciseLogWidget()
        TrainStateWidgetExtensionLiveActivity()
    }
}
