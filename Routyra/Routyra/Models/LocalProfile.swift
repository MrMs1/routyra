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

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.activePlanId = nil
    }

    // MARK: - Computed Properties

    /// Whether the user has an active plan (non-free mode).
    var hasActivePlan: Bool {
        activePlanId != nil
    }
}
