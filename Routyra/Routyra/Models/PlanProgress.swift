//
//  PlanProgress.swift
//  Routyra
//
//  Tracks the user's progress through a workout plan.
//  Stores which day should be shown next and when the app was last opened.
//

import Foundation
import SwiftData

@Model
final class PlanProgress {
    /// Unique identifier.
    var id: UUID

    /// Owner profile ID.
    var profileId: UUID

    /// The workout plan this progress tracks.
    var planId: UUID

    /// The next plan day index to show (1-indexed).
    /// Wraps around when reaching the end of the plan.
    var currentDayIndex: Int

    /// The last date the app was opened (normalized to local start-of-day).
    /// Used to determine if we should advance the plan.
    /// Nil means this is the first time using this plan.
    var lastOpenedDate: Date?

    // MARK: - Initialization

    /// Creates a new plan progress tracker.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan to track.
    ///   - startDayIndex: Initial day index (defaults to 1).
    init(
        profileId: UUID,
        planId: UUID,
        startDayIndex: Int = 1
    ) {
        self.id = UUID()
        self.profileId = profileId
        self.planId = planId
        self.currentDayIndex = startDayIndex
        self.lastOpenedDate = nil
    }

    // MARK: - Methods

    /// Advances to the next day, wrapping around if needed.
    /// - Parameter totalDays: Total number of days in the plan.
    func advanceToNextDay(totalDays: Int) {
        guard totalDays > 0 else { return }
        currentDayIndex = (currentDayIndex % totalDays) + 1
    }

    /// Updates the last opened date to today.
    func updateLastOpenedDate() {
        lastOpenedDate = DateUtilities.startOfDay(Date())
    }

    /// Checks if the last opened date is different from today.
    var isNewDay: Bool {
        guard let lastDate = lastOpenedDate else { return true }
        return !DateUtilities.isSameDay(lastDate, Date())
    }
}
