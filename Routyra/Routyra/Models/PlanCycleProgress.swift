//
//  PlanCycleProgress.swift
//  Routyra
//
//  Tracks progress within a PlanCycle.
//  Maintains current plan index and day index.
//

import Foundation
import SwiftData

@Model
final class PlanCycleProgress {
    /// Unique identifier.
    var id: UUID

    /// Parent cycle (relationship).
    var cycle: PlanCycle?

    /// Current item index within the cycle (0-indexed).
    var currentItemIndex: Int

    /// Current day index within the current plan (0-indexed).
    var currentDayIndex: Int

    /// When the progress was last advanced.
    var lastAdvancedAt: Date?

    /// When the last workout was completed.
    var lastCompletedAt: Date?

    // MARK: - Initialization

    /// Creates a new cycle progress tracker.
    init() {
        self.id = UUID()
        self.currentItemIndex = 0
        self.currentDayIndex = 0
        self.lastAdvancedAt = nil
        self.lastCompletedAt = nil
    }

    // MARK: - Methods

    /// Resets progress to the beginning.
    func reset() {
        currentItemIndex = 0
        currentDayIndex = 0
        lastAdvancedAt = nil
        lastCompletedAt = nil
    }

    /// Advances to the next day within the current plan.
    /// - Parameter totalDays: Total days in the current plan.
    /// - Returns: True if advanced to next plan, false if stayed in current plan.
    @discardableResult
    func advanceDay(totalDays: Int) -> Bool {
        currentDayIndex += 1
        lastAdvancedAt = Date()

        if currentDayIndex >= totalDays {
            currentDayIndex = 0
            return true // Need to advance to next plan
        }
        return false
    }

    /// Advances to the next plan in the cycle.
    /// - Parameter totalItems: Total items in the cycle.
    func advancePlan(totalItems: Int) {
        currentItemIndex += 1
        currentDayIndex = 0
        lastAdvancedAt = Date()

        if currentItemIndex >= totalItems {
            currentItemIndex = 0 // Wrap around to first plan
        }
    }

    /// Marks the current workout as completed.
    func markCompleted() {
        lastCompletedAt = Date()
    }
}
