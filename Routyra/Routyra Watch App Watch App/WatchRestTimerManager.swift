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
import WidgetKit

// MARK: - Timer State

enum WatchTimerState {
    case idle
    case running
    case alarm

    /// SharedTimerStateValue への変換
    func toSharedValue() -> SharedTimerStateValue {
        switch self {
        case .idle: return .idle
        case .running: return .running
        case .alarm: return .alarm
        }
    }
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
    private var isPlayingHaptics: Bool = false

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Starts a new rest timer with the specified duration.
    /// - Parameter duration: Duration in seconds.
    func start(duration: Int) {
        guard state == .idle else { return }

        // Cancel any existing session to prevent duplicates
        session?.invalidate()

        let endTime = Date().addingTimeInterval(TimeInterval(duration))
        endDate = endTime
        totalDuration = duration
        state = .running

        // 1. Start extended runtime session to keep app alive in background
        session = WKExtendedRuntimeSession()
        session?.delegate = self
        session?.start()

        // 2. Start UI update timer (continues in background via session)
        startTicking()

        // 3. Sync state to complication
        syncSharedStateAndReloadComplication()
    }

    /// Stops the timer and resets to idle state.
    func stop() {
        timer?.invalidate()
        timer = nil
        stopAlarmHaptics()
        session?.invalidate()
        session = nil
        state = .idle
        endDate = nil
        totalDuration = 0

        // Sync state to complication
        syncSharedStateAndReloadComplication()
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
        state = .idle
        endDate = nil
        totalDuration = 0

        // Delay complication update to avoid watchOS ignoring rapid reloadTimelines calls
        // (timerCompleted may have just called reloadTimelines with .alarm)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.syncSharedStateAndReloadComplication()
        }
    }

    /// Handles transition to background.
    func handleEnterBackground() {
        // WKExtendedRuntimeSession がプロセスを維持するため、
        // Timer を止めない。バックグラウンドでも tick() が発火し続ける。
    }

    /// Handles return to foreground.
    func handleEnterForeground() {
        // If in alarm state, restart haptics (may have been stopped by session invalidation)
        if state == .alarm {
            startAlarmHaptics()
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

        timerCompleted()
    }

    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        state = .alarm
        startAlarmHaptics()

        // Sync state to complication
        syncSharedStateAndReloadComplication()
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

    // MARK: - Complication Sync

    /// 状態を App Groups に保存し、コンプリケーションを更新
    /// Watch App 側からのみ呼び出す（Widget Extension からは呼ばない）
    private func syncSharedStateAndReloadComplication() {
        let sharedState = SharedTimerState(
            endDate: endDate,
            totalDuration: totalDuration,
            state: state.toSharedValue()
        )
        SharedTimerStateManager.save(sharedState)

        // Widget 更新は Watch App 側からのみ行う
        WidgetCenter.shared.reloadTimelines(ofKind: SharedTimerStateManager.complicationKind)
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
            self.session = nil

            // Stop haptics if not in alarm state
            if self.state != .alarm {
                self.stopAlarmHaptics()
            }
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        // Timer.scheduledTimer が startTicking() で既に動作中。
        // セッションがプロセスを維持するので、追加のスケジューリングは不要。
    }

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        // Session about to expire - can log or handle if needed
    }
}

