//
//  PlannedSet.swift
//  Routyra
//
//  Represents a planned set within a plan exercise.
//  Stores target weight and reps for each set.
//

import Foundation
import SwiftData

@Model
final class PlannedSet {
    /// Unique identifier.
    var id: UUID

    /// Parent plan exercise (relationship).
    var planExercise: PlanExercise?

    /// Order within the exercise (0-indexed).
    var orderIndex: Int

    /// Target weight in kg. Nil means "use previous" or unspecified.
    var targetWeight: Double?

    /// Target reps. Nil means unspecified.
    var targetReps: Int?

    // MARK: - Initialization

    /// Creates a new planned set.
    /// - Parameters:
    ///   - orderIndex: Order within the exercise.
    ///   - targetWeight: Target weight in kg.
    ///   - targetReps: Target number of reps.
    init(
        orderIndex: Int,
        targetWeight: Double? = nil,
        targetReps: Int? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.targetWeight = targetWeight
        self.targetReps = targetReps
    }

    // MARK: - Display Helpers

    /// Formatted weight string.
    var weightString: String {
        if let w = targetWeight {
            return weightStringWithUnit(w)
        }
        return L10n.tr("weight_placeholder")
    }

    /// Formatted reps string.
    var repsString: String {
        if let r = targetReps {
            return "\(r)"
        }
        return "—"
    }

    /// Formatted reps string with unit.
    var repsStringWithUnit: String {
        if let r = targetReps {
            return L10n.tr("reps_with_unit", r)
        }
        return L10n.tr("reps_placeholder")
    }

    /// Summary string for display (e.g., "60kg / 10回").
    var summary: String {
        let weight = targetWeight.map(weightStringWithUnit) ?? L10n.tr("weight_placeholder")
        let reps = targetReps.map { L10n.tr("reps_with_unit", $0) }
            ?? L10n.tr("reps_placeholder")
        return "\(weight) / \(reps)"
    }

    private func weightStringWithUnit(_ weight: Double) -> String {
        let formatted = weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
        return L10n.tr("weight_with_unit", formatted)
    }
}
