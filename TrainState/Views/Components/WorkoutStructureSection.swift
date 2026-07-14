import SwiftUI

struct WorkoutStructureSummaryItem: Identifiable, Hashable {
    let title: String
    let tint: Color
    let symbol: String

    var id: String {
        "\(symbol)-\(title.lowercased())"
    }
}

struct WorkoutStructureSection: View {
    let title: String
    let primaryActionTitle: String
    let primaryActionSubtitle: String
    let primaryAction: () -> Void
    let secondaryActionTitle: String?
    let secondaryActionSubtitle: String?
    let secondaryAction: (() -> Void)?
    let categoryItems: [WorkoutStructureSummaryItem]
    let subcategoryItems: [WorkoutStructureSummaryItem]
    let emptyStateText: String

    var body: some View {
        Section(title) {
            WorkoutStructureActionRow(
                title: primaryActionTitle,
                subtitle: primaryActionSubtitle,
                action: primaryAction
            )

            if let secondaryActionTitle, let secondaryActionSubtitle, let secondaryAction {
                WorkoutStructureActionRow(
                    title: secondaryActionTitle,
                    subtitle: secondaryActionSubtitle,
                    action: secondaryAction
                )
            }

            if !categoryItems.isEmpty {
                WorkoutStructureSummaryGroup(title: "Categories", items: categoryItems)
            }

            if !subcategoryItems.isEmpty {
                WorkoutStructureSummaryGroup(title: "Subcategories", items: subcategoryItems)
            }

            if categoryItems.isEmpty && subcategoryItems.isEmpty && !emptyStateText.isEmpty {
                Text(emptyStateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WorkoutStructureActionRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutStructureSummaryGroup: View {
    let title: String
    let items: [WorkoutStructureSummaryItem]

    private var isCategoryGroup: Bool { title == "Categories" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        if isCategoryGroup {
                            Circle()
                                .fill(item.tint)
                                .frame(width: 8, height: 8)
                                .frame(width: 18)
                        } else {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.tint)
                                .frame(width: 18)
                        }

                        Text(item.title)
                            .font(.subheadline.weight(isCategoryGroup ? .semibold : .regular))
                            .foregroundStyle(isCategoryGroup ? .primary : .secondary)

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}
