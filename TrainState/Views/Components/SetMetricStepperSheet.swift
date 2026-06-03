import SwiftUI

/// Bottom sheet with +/- steppers for editing reps or weight on a set row.
struct SetMetricStepperSheet: View {
    enum Metric: String, Identifiable {
        case reps
        case weight

        var id: String { rawValue }
    }

    let metric: Metric
    let measurementSystem: MeasurementSystem
    @Binding var reps: Int
    @Binding var weight: Double

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.headline)

            Text(valueText)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button {
                    adjust(by: -step)
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    clear()
                } label: {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    adjust(by: step)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }

    private var title: String {
        switch metric {
        case .reps:
            return "Reps"
        case .weight:
            let unit = MeasurementFormatting.weightUnitLabel(for: measurementSystem)
            return "Weight (\(unit))"
        }
    }

    private var valueText: String {
        switch metric {
        case .reps:
            return "\(reps)"
        case .weight:
            let display = MeasurementFormatting.displayWeightFromStorage(weight, system: measurementSystem)
            return MeasurementFormatting.displayWeight(display, system: measurementSystem)
        }
    }

    private var step: Double {
        switch metric {
        case .reps:
            return 1
        case .weight:
            return MeasurementFormatting.weightStep(for: measurementSystem)
        }
    }

    private func adjust(by delta: Double) {
        switch metric {
        case .reps:
            reps = max(Int(Double(reps) + delta), 0)
        case .weight:
            let display = MeasurementFormatting.displayWeightFromStorage(weight, system: measurementSystem)
            let updated = max(display + delta, 0)
            weight = MeasurementFormatting.storageWeight(
                fromDisplayValue: updated,
                system: measurementSystem
            )
        }
        HapticManager.lightImpact()
    }

    private func clear() {
        switch metric {
        case .reps:
            reps = 0
        case .weight:
            weight = 0
        }
        HapticManager.lightImpact()
    }
}

/// Tappable capsule showing a metric label and value (opens stepper sheet).
struct SetMetricCapsuleButton: View {
    let label: String
    let value: String
    var minWidth: CGFloat? = nil
    var valueMinWidth: CGFloat? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
                .frame(minWidth: valueMinWidth, alignment: .trailing)
        }
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(minWidth: minWidth)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
    }
}
