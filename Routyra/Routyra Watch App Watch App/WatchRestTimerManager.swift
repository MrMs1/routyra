//
//  WatchRestTimerManager.swift
//  Routyra Watch App Watch App
//
//  Rest timer manager for watchOS with haptic feedback alarm.
//

import Combine
import Foundation
import SwiftUI
import UserNotifications
import WatchKit

// MARK: - Timer State

enum WatchTimerState {
    case idle
    case running
    case alarm
}

// MARK: - Watch Rest Timer Manager

@MainActor
final class WatchRestTimerManager: NSObject, ObservableObject {
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
    private var session: WKExtendedRuntimeSession?
    private var activeSession: WKExtendedRuntimeSession?
    private let notificationIdentifier = "watchRestTimerNotification"

    // Background state management
    private var backgroundEntryDate: Date?
    private var backgroundTimeRemaining: TimeInterval = 0
    private var isPlayingHaptics: Bool = false

    // Notification category
    private static let notificationCategoryIdentifier = "ROUTYRA_REST_TIMER"
    private static let dismissActionIdentifier = "DISMISS_ALARM"

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Starts a new rest timer with the specified duration.
    /// - Parameter duration: Duration in seconds.
    func start(duration: Int) {
        guard state == .idle else { return }

        // Cancel any existing notification/session to prevent duplicates
        cancelNotification()
        session?.invalidate()
        activeSession = nil

        let endTime = Date().addingTimeInterval(TimeInterval(duration))
        endDate = endTime
        totalDuration = duration
        state = .running

        // 1. Schedule alarm session for background execution
        session = WKExtendedRuntimeSession()
        session?.delegate = self
        session?.start(at: endTime)

        // 2. Schedule notification to ensure screen wake
        scheduleNotification(in: duration)

        // 3. Start UI update timer
        startTicking()
    }

    /// Stops the timer and resets to idle state.
    func stop() {
        timer?.invalidate()
        timer = nil
        stopAlarmHaptics()
        session?.invalidate()
        session = nil
        activeSession = nil
        cancelNotification()
        state = .idle
        endDate = nil
        totalDuration = 0
        backgroundEntryDate = nil
        backgroundTimeRemaining = 0
    }

    /// Skips the current timer and returns to idle.
    func skip() {
        stop()
    }

    /// Dismisses the alarm and returns to idle.
    func dismissAlarm() {
        stopAlarmHaptics()
        session?.invalidate()
        session = nil
        activeSession = nil
        cancelNotification()
        state = .idle
        endDate = nil
        totalDuration = 0
        backgroundEntryDate = nil
        backgroundTimeRemaining = 0
    }

    /// Sets up notification categories with foreground action for fallback.
    func setupNotificationCategories() {
        let dismissAction = UNNotificationAction(
            identifier: Self.dismissActionIdentifier,
            title: "停止",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.notificationCategoryIdentifier,
            actions: [dismissAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Handles transition to background: saves state and stops UI timer.
    func handleEnterBackground() {
        guard state == .running else { return }

        // Save current remaining time and timestamp
        backgroundEntryDate = Date()
        backgroundTimeRemaining = TimeInterval(remainingSeconds)

        // Stop UI timer (WKExtendedRuntimeSession continues)
        timer?.invalidate()
        timer = nil
    }

    /// Handles return to foreground: restores state and corrects elapsed time.
    func handleEnterForeground() {
        // If in alarm state, restart haptics (guard prevents double-play)
        if state == .alarm {
            startAlarmHaptics()
            return
        }

        // If running, correct elapsed time
        guard state == .running, let entryDate = backgroundEntryDate else { return }

        let elapsedTime = Date().timeIntervalSince(entryDate)
        let newTimeRemaining = backgroundTimeRemaining - elapsedTime
        backgroundEntryDate = nil

        if newTimeRemaining <= 0 {
            // Completed while in background (fallback if session failed)
            triggerAlarmIfNeeded()
        } else {
            // Resume timer
            endDate = Date().addingTimeInterval(newTimeRemaining)
            startTicking()
        }
    }

    /// Requests notification permission if not already determined.
    /// Note: getNotificationSettings callback returns on background thread.
    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                ) { _, _ in }
            }
        }
    }

    // MARK: - Private Methods

    private func scheduleNotification(in seconds: Int) {
        // UNTimeIntervalNotificationTrigger requires timeInterval >= 1
        guard seconds >= 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "レスト終了！"
        content.body = "次のセットを始めましょう"
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [notificationIdentifier]
        )
    }

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
            triggerAlarmIfNeeded()
        }
        objectWillChange.send()
    }

    /// Triggers the alarm if the timer is still running (double-fire guard).
    private func triggerAlarmIfNeeded() {
        // Double-fire guard
        guard state == .running else { return }

        // Alarm condition: remaining time is zero or less
        guard remainingSeconds <= 0 else { return }

        // Request watchOS to bring app to foreground via notifyUser
        // repeatHandler: must return > 0 and <= 60 (0 is invalid)
        // Returning 60 means "next haptic in 60 seconds" = effectively single play
        if let session = activeSession ?? session {
            session.notifyUser(hapticType: .notification) { _ in
                return 60.0
            }
        }

        timerCompleted()
    }

    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        state = .alarm
        cancelNotification()  // Cancel notification only when alarm is confirmed
        startAlarmHaptics()
    }

    private func startAlarmHaptics() {
        // Double-play prevention
        guard !isPlayingHaptics else { return }
        isPlayingHaptics = true

        // Play initial haptic
        WKInterfaceDevice.current().play(.notification)

        // Repeat haptic every 1.5 seconds (battery-friendly interval)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private func stopAlarmHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        isPlayingHaptics = false
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchRestTimerManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            // Clear session references
            self.session = nil
            self.activeSession = nil

            // Stop haptics if not in alarm state (notification continues as fallback)
            if self.state != .alarm {
                self.stopAlarmHaptics()
            }
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        Task { @MainActor in
            // Use self.session which was set in start() - it's the same session instance
            // that triggered this callback, avoiding Sendable issues
            self.activeSession = self.session
            // Session started (alarm time reached): trigger alarm with double-fire guard
            self.triggerAlarmIfNeeded()
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        // Session about to expire - can log or handle if needed
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension WatchRestTimerManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Capture action identifier before crossing isolation boundary
        let actionIdentifier = response.actionIdentifier
        Task { @MainActor [actionIdentifier] in
            // Handle foreground action from notification
            if actionIdentifier == Self.dismissActionIdentifier {
                self.dismissAlarm()
            } else if actionIdentifier == UNNotificationDefaultActionIdentifier {
                // User tapped the notification itself - alarm should already be showing
                // but ensure haptics are playing if in alarm state
                if self.state == .alarm {
                    self.startAlarmHaptics()
                }
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // When app is in foreground, suppress notification (alarm UI is visible)
        completionHandler([])
    }
}
