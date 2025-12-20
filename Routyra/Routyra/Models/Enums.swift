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
