//
//  PlanCycleItem.swift
//  Routyra
//
//  An item within a PlanCycle that references a WorkoutPlan.
//  Maintains order within the cycle.
//

import Foundation
import SwiftData

@Model
final class PlanCycleItem {
    /// Unique identifier.
    var id: UUID

    /// Order within the cycle (0-indexed).
    var order: Int

    /// Parent cycle (relationship).
    var cycle: PlanCycle?

    /// Referenced workout plan ID.
    /// Using UUID reference to avoid complex relationship chains.
    var planId: UUID

    /// Optional note for this item.
    var note: String?

    /// Cached plan reference (not persisted, set at runtime).
    @Transient
    var plan: WorkoutPlan?

    // MARK: - Initialization

    /// Creates a new cycle item.
    /// - Parameters:
    ///   - planId: The workout plan ID to reference.
    ///   - order: Order within the cycle.
    ///   - note: Optional note.
    init(planId: UUID, order: Int, note: String? = nil) {
        self.id = UUID()
        self.planId = planId
        self.order = order
        self.note = note
    }

    // MARK: - Computed Properties

    /// Display name from the referenced plan (requires plan to be loaded).
    var displayName: String {
        plan?.name ?? "Unknown Plan"
    }

    /// Summary of the plan (requires plan to be loaded).
    var summary: String {
        guard let plan = plan else { return "" }
        return "\(plan.dayCount)日間 / \(plan.totalExerciseCount)種目"
    }
}
