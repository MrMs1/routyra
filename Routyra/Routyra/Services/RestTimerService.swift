//
//  RestTimerService.swift
//  Routyra
//
//  External API for rest timer functionality.
//  Uses enum namespace pattern following repository conventions.
//  Wraps RestTimerManager for internal implementation.
//

import Foundation

/// Service for managing rest timers between sets.
/// Only one timer can run at a time.
enum RestTimerService {
    // MARK: - Shared Instance

    /// The shared RestTimerManager instance for SwiftUI binding.
    @MainActor
    static var shared: RestTimerManager {
        RestTimerManager.shared
    }

    // MARK: - Timer Control

    /// Starts a new timer with the specified duration.
    /// - Parameter duration: Duration in seconds.
    /// - Returns: true if started, false if timer already running.
    @MainActor
    static func start(duration: Int) -> Bool {
        shared.start(duration: duration)
    }

    /// Force-starts a new timer, cancelling any existing one.
    /// - Parameter duration: Duration in seconds.
    @MainActor
    static func forceStart(duration: Int) {
        shared.forceStart(duration: duration)
    }

    /// Cancels the current timer.
    @MainActor
    static func cancel() {
        shared.cancel()
    }

    /// Adds time to the current timer.
    /// - Parameter seconds: Seconds to add.
    @MainActor
    static func addTime(_ seconds: Int) {
        shared.addTime(seconds)
    }

    /// Dismisses the completed timer state.
    @MainActor
    static func dismiss() {
        shared.dismiss()
    }

    // MARK: - State Accessors

    /// Whether a timer is currently running.
    @MainActor
    static var isRunning: Bool {
        shared.isRunning
    }

    /// Remaining seconds on the current timer.
    @MainActor
    static var remainingSeconds: Int {
        shared.remainingSeconds
    }

    /// Progress from 0.0 to 1.0.
    @MainActor
    static var progress: Double {
        shared.progress
    }

    /// Formatted remaining time string (e.g., "1:30").
    @MainActor
    static var formattedRemaining: String {
        shared.formattedRemaining
    }

    /// Whether the timer has completed.
    @MainActor
    static var isCompleted: Bool {
        shared.isCompleted
    }
}
