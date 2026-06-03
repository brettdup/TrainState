import SwiftUI

/// Standardized row for exercise list items in the unified exercise picker.
struct ExerciseRowView: View {
    let option: ExerciseQuickAddOption
    let subcategoryName: String?
    var affectedSubcategoryNames: [String] = []
    let isSelected: Bool
    var lastUsed: Date?
    var tintColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            // Exercise icon
            Image(systemName: ExerciseIconMapper.icon(for: option.name))
                .font(.system(size: 16))
                .foregroundStyle(ExerciseIconMapper.iconColor(for: option.name))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(ExerciseIconMapper.iconColor(for: option.name).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(option.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let subcategoryName {
                        Text("Main: \(subcategoryName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let lastUsed {
                        if subcategoryName != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(lastUsedText(lastUsed))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !affectedSubcategoryNames.isEmpty {
                    Text("Affects: \(affectedSubcategoryNames.joined(separator: ", "))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? AnyShapeStyle(tintColor) : AnyShapeStyle(.tertiary))
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func lastUsedText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return "Used today"
        } else if days == 1 {
            return "Used yesterday"
        } else if days < 7 {
            return "Used \(days) days ago"
        } else if days < 30 {
            let weeks = days / 7
            return "Used \(weeks)w ago"
        } else {
            let months = days / 30
            return "Used \(months)mo ago"
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ExerciseRowView(
            option: ExerciseQuickAddOption(name: "Bench Press", subcategoryID: UUID()),
            subcategoryName: "Chest",
            isSelected: true,
            lastUsed: Date().addingTimeInterval(-86400 * 2),
            tintColor: .orange
        )
        .padding()

        Divider()

        ExerciseRowView(
            option: ExerciseQuickAddOption(name: "Back Squat", subcategoryID: UUID()),
            subcategoryName: "Legs",
            affectedSubcategoryNames: ["Hamstrings", "Calves"],
            isSelected: false,
            tintColor: .orange
        )
        .padding()

        Divider()

        ExerciseRowView(
            option: ExerciseQuickAddOption(name: "Deadlift", subcategoryID: UUID()),
            subcategoryName: nil,
            isSelected: false,
            lastUsed: Date().addingTimeInterval(-86400 * 14),
            tintColor: .orange
        )
        .padding()
    }
}
