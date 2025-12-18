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

    /// Summary string for display (e.g., "3セット" or "60kg×10 / 60kg×10 / 60kg×10").
    var setsSummary: String {
        if plannedSets.isEmpty {
            return "セット未設定"
        }

        let sorted = sortedPlannedSets
        // Check if all sets have the same weight and reps
        if sorted.count > 1,
           let first = sorted.first,
           sorted.allSatisfy({ $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps }) {
            return "\(first.summary) × \(sorted.count)セット"
        }

        return sorted.map { $0.summary }.joined(separator: " / ")
    }

    /// Compact summary for Plan view (e.g., "3 sets • 8–10 reps • 75–80kg").
    var compactSummary: String {
        let sets = sortedPlannedSets
        guard !sets.isEmpty else {
            return "セット未設定"
        }

        let setsCount = sets.count
        let weights = sets.compactMap(\.targetWeight)
        let reps = sets.compactMap(\.targetReps)

        var parts: [String] = ["\(setsCount)セット"]

        if !reps.isEmpty {
            let minReps = reps.min()!
            let maxReps = reps.max()!
            if minReps == maxReps {
                parts.append("\(minReps)reps")
            } else {
                parts.append("\(minReps)–\(maxReps)reps")
            }
        }

        if !weights.isEmpty {
            let minWeight = weights.min()!
            let maxWeight = weights.max()!
            let formatWeight: (Double) -> String = { w in
                w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
            }
            if minWeight == maxWeight {
                parts.append("\(formatWeight(minWeight))kg")
            } else {
                parts.append("\(formatWeight(minWeight))–\(formatWeight(maxWeight))kg")
            }
        }

        return parts.joined(separator: " • ")
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
