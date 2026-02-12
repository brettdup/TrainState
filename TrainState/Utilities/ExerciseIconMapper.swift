import SwiftUI

/// Maps exercise names to appropriate SF Symbols icons.
enum ExerciseIconMapper {
    /// Returns an appropriate SF Symbol name for the given exercise name.
    static func icon(for exerciseName: String) -> String {
        let lowercased = exerciseName.lowercased()

        // Barbell exercises
        if lowercased.contains("barbell") ||
           lowercased.contains("deadlift") ||
           lowercased.contains("squat") ||
           lowercased.contains("bench press") ||
           lowercased.contains("overhead press") ||
           lowercased.contains("clean") ||
           lowercased.contains("snatch") ||
           lowercased.contains("row") && !lowercased.contains("cable") {
            return "figure.strengthtraining.traditional"
        }

        // Dumbbell exercises
        if lowercased.contains("dumbbell") ||
           lowercased.contains("curl") ||
           lowercased.contains("fly") ||
           lowercased.contains("raise") ||
           lowercased.contains("extension") ||
           lowercased.contains("kickback") ||
           lowercased.contains("shrug") {
            return "dumbbell.fill"
        }

        // Cable/machine exercises
        if lowercased.contains("cable") ||
           lowercased.contains("machine") ||
           lowercased.contains("pulldown") ||
           lowercased.contains("pushdown") ||
           lowercased.contains("lat pull") ||
           lowercased.contains("chest press") ||
           lowercased.contains("leg press") ||
           lowercased.contains("leg curl") ||
           lowercased.contains("leg extension") ||
           lowercased.contains("pec deck") ||
           lowercased.contains("smith") {
            return "gearshape.fill"
        }

        // Pull-up/bodyweight upper
        if lowercased.contains("pull-up") ||
           lowercased.contains("pullup") ||
           lowercased.contains("chin-up") ||
           lowercased.contains("chinup") ||
           lowercased.contains("dip") {
            return "figure.strengthtraining.functional"
        }

        // Push-up/bodyweight
        if lowercased.contains("push-up") ||
           lowercased.contains("pushup") ||
           lowercased.contains("plank") ||
           lowercased.contains("crunch") ||
           lowercased.contains("sit-up") ||
           lowercased.contains("situp") ||
           lowercased.contains("burpee") {
            return "figure.core.training"
        }

        // Cardio exercises
        if lowercased.contains("run") ||
           lowercased.contains("jog") ||
           lowercased.contains("sprint") {
            return "figure.run"
        }

        if lowercased.contains("cycle") ||
           lowercased.contains("bike") ||
           lowercased.contains("spin") {
            return "bicycle"
        }

        if lowercased.contains("swim") {
            return "figure.pool.swim"
        }

        if lowercased.contains("row") && lowercased.contains("erg") ||
           lowercased.contains("rowing machine") {
            return "figure.rower"
        }

        if lowercased.contains("jump") ||
           lowercased.contains("box") ||
           lowercased.contains("skip") {
            return "figure.jumprope"
        }

        // Stretching/flexibility
        if lowercased.contains("stretch") ||
           lowercased.contains("yoga") ||
           lowercased.contains("mobility") {
            return "figure.flexibility"
        }

        // Kettlebell
        if lowercased.contains("kettlebell") ||
           lowercased.contains("swing") {
            return "figure.highintensity.intervaltraining"
        }

        // Default fallback
        return "dumbbell.fill"
    }

    /// Returns a color for the exercise icon based on exercise type.
    static func iconColor(for exerciseName: String) -> Color {
        let icon = icon(for: exerciseName)

        switch icon {
        case "figure.strengthtraining.traditional":
            return .orange
        case "dumbbell.fill":
            return .blue
        case "gearshape.fill":
            return .purple
        case "figure.strengthtraining.functional":
            return .green
        case "figure.core.training":
            return .red
        case "figure.run":
            return .cyan
        case "bicycle":
            return .teal
        case "figure.pool.swim":
            return .blue
        case "figure.rower":
            return .indigo
        case "figure.jumprope":
            return .pink
        case "figure.flexibility":
            return .mint
        case "figure.highintensity.intervaltraining":
            return .yellow
        default:
            return .gray
        }
    }
}
