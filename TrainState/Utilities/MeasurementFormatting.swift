import Foundation
import SwiftData

enum MeasurementFormatting {
    static func preferredSystem(from settings: [UserSettings]) -> MeasurementSystem {
        settings.first?.measurementSystem ?? .metric
    }

    static func weightUnitLabel(for system: MeasurementSystem) -> String {
        system == .imperial ? "lb" : "kg"
    }

    static func weightStep(for system: MeasurementSystem) -> Double {
        system == .imperial ? 5 : 2.5
    }

    static func displayWeight(_ value: Double, system: MeasurementSystem) -> String {
        let displayValue = system == .imperial ? value * 2.20462 : value
        if displayValue.rounded() == displayValue {
            return String(Int(displayValue.rounded()))
        }
        return String(format: "%.1f", displayValue)
    }

    static func storageWeight(fromDisplayValue displayValue: Double, system: MeasurementSystem) -> Double {
        guard system == .imperial else { return max(displayValue, 0) }
        return max(displayValue / 2.20462, 0)
    }

    static func displayWeightFromStorage(_ storageKg: Double, system: MeasurementSystem) -> Double {
        guard system == .imperial else { return storageKg }
        return storageKg * 2.20462
    }
}
