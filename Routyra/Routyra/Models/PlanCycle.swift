//
//  PlanCycle.swift
//  Routyra
//
//  A cycle that bundles multiple WorkoutPlans in sequence.
//  Users can rotate through plans (Plan1 → Plan2 → Plan3 → Plan1...).
//

import Foundation
import SwiftData

@Model
final class PlanCycle {
    /// Unique identifier.
    var id: UUID

    /// Owner profile ID.
    var profileId: UUID

    /// Display name of the cycle (e.g., "Main Rotation", "Competition Prep").
    var name: String

    /// Whether this cycle is currently active.
    /// Only one cycle should be active at a time.
    var isActive: Bool

    /// Plans within this cycle (ordered).
    @Relationship(deleteRule: .cascade, inverse: \PlanCycleItem.cycle)
    var items: [PlanCycleItem]

    /// Progress tracker for this cycle (1:1).
    @Relationship(deleteRule: .cascade, inverse: \PlanCycleProgress.cycle)
    var progress: PlanCycleProgress?

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    /// Creates a new plan cycle.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - name: Display name.
    init(profileId: UUID, name: String) {
        self.id = UUID()
        self.profileId = profileId
        self.name = name
        self.isActive = false
        self.items = []
        self.progress = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// Items sorted by order.
    var sortedItems: [PlanCycleItem] {
        items.sorted { $0.order < $1.order }
    }

    /// Number of plans in this cycle.
    var planCount: Int {
        items.count
    }

    /// Whether this cycle has any plans.
    var hasPlans: Bool {
        !items.isEmpty
    }

    /// Current plan based on progress.
    var currentPlan: WorkoutPlan? {
        guard let progress = progress,
              progress.currentItemIndex < sortedItems.count else {
            return sortedItems.first?.plan
        }
        return sortedItems[progress.currentItemIndex].plan
    }

    /// Current day index based on progress (0-indexed internally).
    var currentDayIndex: Int {
        progress?.currentDayIndex ?? 0
    }

    /// Current plan item based on progress.
    var currentItem: PlanCycleItem? {
        guard let progress = progress,
              progress.currentItemIndex < sortedItems.count else {
            return sortedItems.first
        }
        return sortedItems[progress.currentItemIndex]
    }

    // MARK: - Methods

    /// Marks the cycle as updated.
    func touch() {
        self.updatedAt = Date()
    }

    /// Adds a plan to this cycle.
    func addItem(_ item: PlanCycleItem) {
        items.append(item)
        touch()
    }

    /// Removes an item from this cycle.
    func removeItem(_ item: PlanCycleItem) {
        items.removeAll { $0.id == item.id }
        touch()
    }

    /// Reindexes items after reordering (0-indexed).
    func reindexItems() {
        for (index, item) in sortedItems.enumerated() {
            item.order = index
        }
        touch()
    }
}
