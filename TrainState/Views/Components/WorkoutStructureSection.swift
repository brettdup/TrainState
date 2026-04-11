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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(items) { item in
                Label {
                    Text(item.title)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: item.symbol)
                        .foregroundStyle(item.tint)
                }
            }
        }
        .padding(.top, 4)
    }
}
