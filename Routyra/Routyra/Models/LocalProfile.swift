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

    /// Scheduled plan start date (start of day), or nil for immediate start.
    var scheduledPlanStartDate: Date?

    /// Scheduled plan day index to start from.
    var scheduledPlanStartDayIndex: Int?

    /// Scheduled plan ID (guards against applying the wrong plan).
    var scheduledPlanId: UUID?

    /// Scheduled cycle start date (start of day), or nil for immediate start.
    var scheduledCycleStartDate: Date?

    /// Scheduled cycle start plan index (0-indexed).
    var scheduledCyclePlanIndex: Int?

    /// Scheduled cycle start day index (0-indexed).
    var scheduledCycleDayIndex: Int?

    /// Scheduled cycle ID (guards against applying the wrong cycle).
    var scheduledCycleId: UUID?

    /// The execution mode for workouts (single plan or cycle).
    var executionMode: ExecutionMode

    /// The hour at which the workout day transitions to the next day.
    /// Default is 3 (3:00 AM). Range: 0-23.
    /// For example, if set to 3, workouts after midnight but before 3am
    /// will still be counted as the previous day.
    var dayTransitionHour: Int

    /// Whether to ask for confirmation before updating plan values.
    var planUpdateConfirmationEnabled: Bool

    /// Plan update policy when workout values are higher than the plan.
    var planUpdatePolicyIncrease: PlanUpdatePolicy

    /// Plan update policy when workout values are lower than the plan.
    var planUpdatePolicyDecrease: PlanUpdatePolicy

    // MARK: - Rest Timer Settings

    /// Default rest time in seconds for new sets (range: 0-1200, default: 90 = 1:30).
    var defaultRestTimeSeconds: Int

    /// Whether to combine the "Log set" button with timer start.
    /// When true, logging a set automatically starts the rest timer if restTime > 0.
    var combineRecordAndTimerStart: Bool

    /// Whether the combination mode announcement has been shown.
    var hasShownCombinationAnnouncement: Bool

    /// Whether to skip rest timer on the final set of each exercise (default: true).
    /// Uses property default for SwiftData migration safety.
    var skipRestTimerOnFinalSet: Bool = true

    // MARK: - Display Settings

    /// The unit for displaying weight values (kg or lb).
    /// Optional for backward compatibility with existing data.
    var weightUnit: WeightUnit?

    /// The color theme for the app.
    /// Optional for backward compatibility with existing data.
    var themeType: ThemeType?

    var showCardioInHistory: Bool = true

    // MARK: - Notification Settings

    /// Whether notifications are enabled globally.
    var notificationsEnabled: Bool?

    // MARK: - Premium Settings

    /// Whether the user has purchased ad removal.
    var isPremiumUser: Bool?

    // MARK: - HealthKit Settings

    /// Last HealthKit sync date (nil = never synced).
    var lastHealthKitSyncDate: Date?

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.activePlanId = nil
        self.scheduledPlanStartDate = nil
        self.scheduledPlanStartDayIndex = nil
        self.scheduledPlanId = nil
        self.scheduledCycleStartDate = nil
        self.scheduledCyclePlanIndex = nil
        self.scheduledCycleDayIndex = nil
        self.scheduledCycleId = nil
        self.executionMode = .single
        self.dayTransitionHour = 3
        self.planUpdateConfirmationEnabled = true
        self.planUpdatePolicyIncrease = .confirm
        self.planUpdatePolicyDecrease = .confirm
        self.defaultRestTimeSeconds = 90  // 1:30
        self.combineRecordAndTimerStart = false
        self.hasShownCombinationAnnouncement = false
        self.weightUnit = .kg
        self.themeType = .dark
        self.showCardioInHistory = true
    }

    // MARK: - Computed Properties

    /// Whether the user has an active plan (non-free mode).
    var hasActivePlan: Bool {
        activePlanId != nil
    }

    /// Effective weight unit (defaults to .kg if not set).
    var effectiveWeightUnit: WeightUnit {
        weightUnit ?? .kg
    }

    /// Effective theme type (defaults to .dark if not set).
    var effectiveThemeType: ThemeType {
        themeType ?? .dark
    }
}
