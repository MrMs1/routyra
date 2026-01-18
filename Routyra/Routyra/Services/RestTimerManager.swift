//
//  RestTimerManager.swift
//  Routyra
//
//  Internal implementation of rest timer functionality.
//  Uses ObservableObject for SwiftUI binding.
//  Background-safe using startDate/endDate for time calculation.
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class RestTimerManager: ObservableObject {
    // MARK: - Singleton

    static let shared = RestTimerManager()

    // MARK: - Published State

    /// Whether the timer is currently running.
    @Published private(set) var isRunning: Bool = false

    /// The target end time for the timer.
    @Published private(set) var endDate: Date?

    /// The total duration of the current timer in seconds.
    @Published private(set) var totalDuration: Int = 0

    /// The start time of the current timer.
    @Published private(set) var startDate: Date?

    // MARK: - Computed Properties

    /// Remaining seconds calculated from endDate.
    /// This is background-safe as it recalculates from the actual end time.
    var remainingSeconds: Int {
        guard let end = endDate else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    /// Progress from 0.0 to 1.0.
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = totalDuration - remainingSeconds
        return min(1.0, max(0.0, Double(elapsed) / Double(totalDuration)))
    }

    /// Formatted remaining time string (e.g., "1:30").
    var formattedRemaining: String {
        let remaining = remainingSeconds
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Whether the timer has completed (was running and now finished).
    var isCompleted: Bool {
        guard endDate != nil else { return false }
        return remainingSeconds == 0
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private var notificationId: String?
    private var notificationDetail: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Starts a new timer with the specified duration.
    /// - Parameter duration: Duration in seconds.
    /// - Returns: true if started, false if timer already running.
    func start(duration: Int, notificationDetail: String? = nil) -> Bool {
        guard !isRunning else { return false }

        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(TimeInterval(duration))
        totalDuration = duration
        isRunning = true
        self.notificationDetail = notificationDetail

        requestNotificationPermissionIfNeeded()
        scheduleNotification(in: duration)
        startTicking()

        return true
    }

    /// Force-starts a new timer, cancelling any existing one.
    /// - Parameter duration: Duration in seconds.
    func forceStart(duration: Int) {
        cancel()
        _ = start(duration: duration)
    }

    /// Cancels the current timer.
    func cancel() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        startDate = nil
        endDate = nil
        totalDuration = 0
        notificationDetail = nil
        cancelNotification()
    }

    /// Adds time to the current timer.
    /// - Parameter seconds: Seconds to add.
    func addTime(_ seconds: Int) {
        guard isRunning, let currentEnd = endDate else { return }

        endDate = currentEnd.addingTimeInterval(TimeInterval(seconds))
        totalDuration += seconds
        rescheduleNotification()
    }

    /// Resets the completed state by clearing the timer.
    func dismiss() {
        if isCompleted {
            startDate = nil
            endDate = nil
            totalDuration = 0
            notificationDetail = nil
        }
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
        // Trigger UI update by checking remaining time
        if remainingSeconds <= 0 {
            completeTimer()
        }
        // Force objectWillChange to update UI
        objectWillChange.send()
    }

    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        // Keep endDate for display until dismissed
    }

    // MARK: - Notifications

    private func scheduleNotification(in seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("rest_timer_complete_title")
        if let detail = notificationDetail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.body = detail
        } else {
            // Keep empty body to avoid redundant messaging.
            content.body = ""
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )

        let id = UUID().uuidString
        notificationId = id

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        if let id = notificationId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            notificationId = nil
        }
    }

    private func rescheduleNotification() {
        cancelNotification()
        let remaining = remainingSeconds
        if remaining > 0 {
            scheduleNotification(in: remaining)
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }
}
