import Foundation

enum ExerciseSetPlanSerializer {
    static func setEntries(from exercise: WorkoutExercise) -> [ExerciseSetEntry] {
        if let jsonEntries = decodeJSON(exercise.setPlanJSON), !jsonEntries.isEmpty {
            return jsonEntries
        }
        return parseNotes(exercise.notes)
    }

    static func setEntries(from notes: String?) -> [ExerciseSetEntry] {
        parseNotes(notes)
    }

    static func notes(from setEntries: [ExerciseSetEntry]) -> String? {
        let lines = setEntries.enumerated().map { index, set in
            "Set \(index + 1): \(set.summary)"
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func encodeJSON(_ setEntries: [ExerciseSetEntry]) -> String? {
        guard !setEntries.isEmpty else { return nil }
        let payload = setEntries.map {
            TemplateSetPlanEntry(
                reps: max($0.reps, 0),
                weight: max($0.weight, 0),
                isCompleted: $0.isCompleted
            )
        }
        return StrengthWorkoutTemplateExercise.encodeSetPlan(payload)
    }

    private static func decodeJSON(_ json: String?) -> [ExerciseSetEntry]? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let plan = (try? JSONDecoder().decode([TemplateSetPlanEntry].self, from: data)) ?? []
        guard !plan.isEmpty else { return nil }
        return plan.map {
            ExerciseSetEntry(
                reps: max($0.reps, 0),
                weight: max($0.weight, 0),
                isCompleted: $0.isCompleted ?? false
            )
        }
    }

    private static func parseNotes(_ notes: String?) -> [ExerciseSetEntry] {
        guard let notes, !notes.isEmpty else { return [] }
        return notes
            .split(separator: "\n")
            .compactMap { parseNoteLine(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func parseNoteLine(_ line: String) -> ExerciseSetEntry? {
        guard let separator = line.range(of: ": ") else { return nil }
        let detail = String(line[separator.upperBound...])
        let isCompleted = detail.hasPrefix("Done - ")
        let normalizedDetail = isCompleted ? String(detail.dropFirst("Done - ".count)) : detail

        let pattern = #"^\s*(\d+)\s+reps\s+@\s+([0-9]+(?:\.[0-9]+)?)\s+kg\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: normalizedDetail,
                range: NSRange(normalizedDetail.startIndex..., in: normalizedDetail)
              ),
              let repsRange = Range(match.range(at: 1), in: normalizedDetail),
              let weightRange = Range(match.range(at: 2), in: normalizedDetail),
              let reps = Int(normalizedDetail[repsRange]),
              let weight = Double(normalizedDetail[weightRange]) else {
            return nil
        }

        return ExerciseSetEntry(reps: reps, weight: weight, isCompleted: isCompleted)
    }
}
