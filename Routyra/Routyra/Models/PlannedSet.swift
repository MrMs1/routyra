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
            return w.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(w))kg"
                : String(format: "%.1fkg", w)
        }
        return "-"
    }

    /// Formatted reps string.
    var repsString: String {
        if let r = targetReps {
            return "\(r)"
        }
        return "-"
    }

    /// Formatted reps string with unit.
    var repsStringWithUnit: String {
        if let r = targetReps {
            return "\(r)回"
        }
        return "—回"
    }

    /// Summary string for display (e.g., "60kg / 10回").
    var summary: String {
        let weight = targetWeight.map { w in
            w.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(w))kg"
                : String(format: "%.1fkg", w)
        } ?? "—kg"
        let reps = targetReps.map { "\($0)回" } ?? "—回"
        return "\(weight) / \(reps)"
    }
}
