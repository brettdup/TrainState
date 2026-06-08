import SwiftUI

struct RatingPickerTarget: Identifiable, Hashable {
    let context: String
    let sourceID: UUID
    let title: String
    let subtitle: String
    let clearTitle: String

    var id: String {
        "\(context)-\(sourceID.uuidString)"
    }
}

struct RatingPickerSheet: View {
    let title: String
    let subtitle: String
    let clearTitle: String
    let tintColor: Color
    @Binding var rating: Int?
    @State private var draftRating: Int?

    private var currentRating: Int {
        min(max(draftRating ?? 5, 1), 10)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(draftRating.map { "\($0)" } ?? "No Rating")
                .font(.system(size: draftRating == nil ? 34 : 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(height: 68)

            HStack(spacing: 16) {
                Button {
                    adjust(by: -1)
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftRating == nil || currentRating <= 1)

                Button {
                    draftRating = nil
                } label: {
                    Text(clearTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    adjust(by: 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftRating != nil && currentRating >= 10)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        draftRating = value
                    } label: {
                        Text("\(value)")
                            .font(.headline.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(value == draftRating ? tintColor : nil)
                }
            }
        }
        .padding(24)
        .onAppear {
            draftRating = rating
        }
        .onDisappear {
            rating = draftRating
        }
    }

    private func adjust(by delta: Int) {
        guard let draftRating else {
            if delta > 0 {
                self.draftRating = 1
            }
            return
        }

        self.draftRating = min(max(draftRating + delta, 1), 10)
    }
}

struct RatingPickerRow: View {
    let title: String
    let rating: Int?
    let placeholder: String
    let tintColor: Color
    var systemImage: String = "gauge.medium"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tintColor)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            if let rating {
                Text("\(rating)/10")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: 44, alignment: .trailing)
            } else {
                Text(placeholder)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
