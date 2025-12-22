//
//  PlanExercise.swift
//  Routyra
//
//  Represents an exercise within a plan day.
//  Links to an exercise definition and contains planned sets.
//

import Foundation
import SwiftData

@Model
final class PlanExercise {
    /// Unique identifier.
    var id: UUID

    /// Parent plan day (relationship).
    var planDay: PlanDay?

    /// Reference to the exercise definition.
    /// Using UUID instead of relationship to keep Exercise independent.
    var exerciseId: UUID

    /// Display order within the plan day (0-indexed).
    var orderIndex: Int

    /// Number of sets planned for this exercise (legacy, kept for backward compatibility).
    var plannedSetCount: Int

    /// Planned sets with detailed weight/reps info.
    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.planExercise)
    var plannedSets: [PlannedSet]

    // MARK: - Initialization

    /// Creates a new plan exercise.
    /// - Parameters:
    ///   - exerciseId: Reference to the exercise definition.
    ///   - orderIndex: Display order.
    ///   - plannedSetCount: Target number of sets.
    init(
        exerciseId: UUID,
        orderIndex: Int,
        plannedSetCount: Int
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.plannedSetCount = plannedSetCount
        self.plannedSets = []
    }

    // MARK: - Computed Properties

    /// Planned sets sorted by order.
    var sortedPlannedSets: [PlannedSet] {
        plannedSets.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Effective set count (uses plannedSets count if available, otherwise plannedSetCount).
    var effectiveSetCount: Int {
        plannedSets.isEmpty ? plannedSetCount : plannedSets.count
    }

    /// Summary string for display (e.g., "60kg / 10回 / 3セット").
    var setsSummary: String {
        if plannedSets.isEmpty {
            return L10n.tr("plan_sets_not_configured")
        }

        let sorted = sortedPlannedSets
        let setCount = sorted.count

        // Check if all sets have the same weight and reps
        if sorted.count > 1,
           let first = sorted.first,
           sorted.allSatisfy({ $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps }) {
            // Format: "60kg / 10回 / 3セット"
            let weight = first.targetWeight.map(weightString) ?? L10n.tr("weight_placeholder")
            let reps = first.targetReps.map(repsString) ?? L10n.tr("reps_placeholder")
            let sets = setsString(setCount)
            return "\(weight) / \(reps) / \(sets)"
        }

        // Different sets - show count and range
        let weights = sorted.compactMap(\.targetWeight)
        let reps = sorted.compactMap(\.targetReps)

        var parts: [String] = []

        if !weights.isEmpty {
            let minWeight = weights.min()!
            let maxWeight = weights.max()!
            if minWeight == maxWeight {
                parts.append(weightString(minWeight))
            } else {
                parts.append(weightRangeString(minWeight, maxWeight))
            }
        } else {
            parts.append(L10n.tr("weight_placeholder"))
        }

        if !reps.isEmpty {
            let minReps = reps.min()!
            let maxReps = reps.max()!
            if minReps == maxReps {
                parts.append(repsString(minReps))
            } else {
                parts.append(repsRangeString(minReps, maxReps))
            }
        } else {
            parts.append(L10n.tr("reps_placeholder"))
        }

        parts.append(setsString(setCount))

        return parts.joined(separator: " / ")
    }

    /// Compact summary for Plan view (e.g., "3 sets • 8–10 reps • 75–80kg").
    var compactSummary: String {
        let sets = sortedPlannedSets
        guard !sets.isEmpty else {
            return L10n.tr("plan_sets_not_configured")
        }

        let setsCount = sets.count
        let weights = sets.compactMap(\.targetWeight)
        let reps = sets.compactMap(\.targetReps)

        var parts: [String] = [setsString(setsCount)]

        if !reps.isEmpty {
            let minReps = reps.min()!
            let maxReps = reps.max()!
            if minReps == maxReps {
                parts.append(repsString(minReps))
            } else {
                parts.append(repsRangeString(minReps, maxReps))
            }
        }

        if !weights.isEmpty {
            let minWeight = weights.min()!
            let maxWeight = weights.max()!
            if minWeight == maxWeight {
                parts.append(weightString(minWeight))
            } else {
                parts.append(weightRangeString(minWeight, maxWeight))
            }
        }

        return parts.joined(separator: " • ")
    }

    private func formatWeightValue(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }

    private func weightString(_ weight: Double) -> String {
        L10n.tr("weight_with_unit", formatWeightValue(weight))
    }

    private func weightRangeString(_ min: Double, _ max: Double) -> String {
        L10n.tr("weight_range_with_unit", formatWeightValue(min), formatWeightValue(max))
    }

    private func repsString(_ reps: Int) -> String {
        L10n.tr("reps_with_unit", reps)
    }

    private func repsRangeString(_ min: Int, _ max: Int) -> String {
        L10n.tr("reps_range_with_unit", min, max)
    }

    private func setsString(_ count: Int) -> String {
        L10n.tr("sets_with_unit", count)
    }

    // MARK: - Methods

    /// Updates the planned set count (legacy).
    func updatePlannedSets(_ count: Int) {
        self.plannedSetCount = max(0, count)
    }

    /// Adds a planned set.
    func addPlannedSet(_ set: PlannedSet) {
        plannedSets.append(set)
    }

    /// Creates and adds a new planned set.
    @discardableResult
    func createPlannedSet(weight: Double? = nil, reps: Int? = nil) -> PlannedSet {
        let nextOrder = (plannedSets.map(\.orderIndex).max() ?? -1) + 1
        let set = PlannedSet(orderIndex: nextOrder, targetWeight: weight, targetReps: reps)
        addPlannedSet(set)
        return set
    }

    /// Removes a planned set.
    func removePlannedSet(_ set: PlannedSet) {
        plannedSets.removeAll { $0.id == set.id }
    }

    /// Reindexes planned sets after reordering.
    func reindexPlannedSets() {
        for (index, set) in sortedPlannedSets.enumerated() {
            set.orderIndex = index
        }
    }
}
