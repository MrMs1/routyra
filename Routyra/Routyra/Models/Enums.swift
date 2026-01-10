//
//  Enums.swift
//  Routyra
//
//  Domain enums for the workout logging app.
//  All enums conform to Codable for SwiftData persistence.
//

import Foundation

// MARK: - Execution Mode

/// Defines how the user executes their workout routine.
enum ExecutionMode: String, Codable, CaseIterable {
    /// Single plan mode: user selects one active plan.
    case single
    /// Cycle mode: user rotates through multiple plans in a cycle.
    case cycle
}

// MARK: - Exercise Scope

/// Defines whether an exercise is a global preset or user-created.
enum ExerciseScope: String, Codable, CaseIterable {
    /// Preloaded/fixed exercises available to all users.
    case global
    /// User-created custom exercises.
    case user
}

// MARK: - Workout Mode

/// Defines the mode of a workout day.
enum WorkoutMode: String, Codable, CaseIterable {
    /// Free mode: user adds exercises ad-hoc without a routine.
    case free
    /// Routine mode: exercises come from an active routine preset.
    case routine
}

// MARK: - Entry Source

/// Indicates how an exercise entry was added to a workout.
enum EntrySource: String, Codable, CaseIterable {
    /// Entry was auto-populated from a routine.
    case routine
    /// Entry was manually added by the user (free mode or additional exercise).
    case free
}

// MARK: - Set Metric Type

/// The type of metrics tracked for a set.
/// Determines what input fields are shown and how volume is calculated.
enum SetMetricType: String, Codable, CaseIterable {
    /// Weight and repetitions (default - e.g., bench press, deadlift).
    case weightReps
    /// Bodyweight repetitions only (e.g., pull-ups, push-ups).
    case bodyweightReps
    /// Time and optional distance (e.g., running, planks).
    case timeDistance
    /// Simple completion marker (e.g., stretches, warm-up).
    case completion

    /// Whether this metric type supports volume calculation (weight × reps).
    var supportsVolume: Bool {
        self == .weightReps
    }

    /// Localized display name for the metric type.
    var localizedName: String {
        switch self {
        case .weightReps:
            return L10n.tr("metric_type_weight_reps")
        case .bodyweightReps:
            return L10n.tr("metric_type_bodyweight_reps")
        case .timeDistance:
            return L10n.tr("metric_type_time_distance")
        case .completion:
            return L10n.tr("metric_type_completion")
        }
    }

    /// Returns allowed metric types based on whether the body part is cardio.
    /// - Parameter isCardio: True if the body part is cardio (code == "cardio").
    /// - Returns: Array of allowed metric types.
    static func allowedTypes(isCardio: Bool) -> [SetMetricType] {
        if isCardio {
            // Cardio: time/distance only (completion handled by CardioWorkout)
            return [.timeDistance]
        } else {
            // Other body parts: weight/reps and bodyweight only
            return [.weightReps, .bodyweightReps]
        }
    }

    /// Returns the default metric type for a body part.
    static func defaultType(isCardio: Bool) -> SetMetricType {
        isCardio ? .timeDistance : .weightReps
    }
}

// MARK: - Weight Unit

/// The unit for displaying weight values.
enum WeightUnit: String, Codable, CaseIterable {
    /// Kilograms (metric).
    case kg
    /// Pounds (imperial).
    case lb

    /// Localized display name for the unit.
    var localizedName: String {
        switch self {
        case .kg:
            return L10n.tr("weight_unit_kg")
        case .lb:
            return L10n.tr("weight_unit_lb")
        }
    }

    /// Short symbol for display next to values.
    var symbol: String {
        switch self {
        case .kg:
            return L10n.tr("unit_kg")
        case .lb:
            return L10n.tr("unit_lb")
        }
    }
}

// MARK: - Cardio Source

/// Indicates the source of a cardio workout record.
enum CardioSource: String, Codable, CaseIterable {
    /// Manually recorded by the user within the app.
    case manual
    /// Imported from HealthKit.
    case healthKit
}

// MARK: - Plan Update Policy

/// Defines how plan updates are applied when workout values change.
enum PlanUpdatePolicy: String, Codable, CaseIterable {
    /// Ask for confirmation before updating the plan.
    case confirm
    /// Update the plan automatically without confirmation.
    case autoUpdate

    /// Localized display name for settings.
    var localizedName: String {
        switch self {
        case .confirm:
            return L10n.tr("plan_update_policy_confirm")
        case .autoUpdate:
            return L10n.tr("plan_update_policy_auto")
        }
    }
}
