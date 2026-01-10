//
//  WatchRestTimerManager.swift
//  Routyra Watch App Watch App
//
//  Rest timer manager for watchOS with haptic feedback alarm.
//

import Combine
import Foundation
import SwiftUI
import WatchKit

// MARK: - Timer State

enum WatchTimerState {
    case idle
    case running
    case alarm
}

// MARK: - Watch Rest Timer Manager

@MainActor
final class WatchRestTimerManager: ObservableObject {
    // MARK: - Singleton

    static let shared = WatchRestTimerManager()

    // MARK: - Published State

    @Published private(set) var state: WatchTimerState = .idle
    @Published private(set) var endDate: Date?
    @Published private(set) var totalDuration: Int = 0

    // MARK: - Computed Properties

    var remainingSeconds: Int {
        guard let end = endDate else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = totalDuration - remainingSeconds
        return min(1.0, max(0.0, Double(elapsed) / Double(totalDuration)))
    }

    var formattedRemaining: String {
        let remaining = remainingSeconds
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private var hapticTimer: Timer?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Starts a new rest timer with the specified duration.
    /// - Parameter duration: Duration in seconds.
    func start(duration: Int) {
        guard state == .idle else { return }

        let now = Date()
        endDate = now.addingTimeInterval(TimeInterval(duration))
        totalDuration = duration
        state = .running

        startTicking()
    }

    /// Stops the timer and resets to idle state.
    func stop() {
        timer?.invalidate()
        timer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
        state = .idle
        endDate = nil
        totalDuration = 0
    }

    /// Skips the current timer and returns to idle.
    func skip() {
        stop()
    }

    /// Dismisses the alarm and returns to idle.
    func dismissAlarm() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        state = .idle
        endDate = nil
        totalDuration = 0
    }

    // MARK: - Private Methods

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        if remainingSeconds <= 0 {
            timerCompleted()
        }
        objectWillChange.send()
    }

    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        state = .alarm
        startAlarmHaptics()
    }

    private func startAlarmHaptics() {
        // Play initial haptic
        WKInterfaceDevice.current().play(.notification)

        // Repeat haptic every 1.5 seconds
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
