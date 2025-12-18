//
//  LocalProfile.swift
//  Routyra
//
//  The root profile object for the local user.
//  Generated on first app launch. No authentication required.
//

import Foundation
import SwiftData

@Model
final class LocalProfile {
    /// Unique identifier for this profile.
    var id: UUID

    /// When this profile was created.
    var createdAt: Date

    /// The currently active workout plan ID, or nil for free mode.
    /// Using UUID reference instead of relationship to avoid circular complexity.
    var activePlanId: UUID?

    /// The hour at which the workout day transitions to the next day.
    /// Default is 3 (3:00 AM). Range: 0-23.
    /// For example, if set to 3, workouts after midnight but before 3am
    /// will still be counted as the previous day.
    var dayTransitionHour: Int

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.activePlanId = nil
        self.dayTransitionHour = 3
    }

    // MARK: - Computed Properties

    /// Whether the user has an active plan (non-free mode).
    var hasActivePlan: Bool {
        activePlanId != nil
    }
}
