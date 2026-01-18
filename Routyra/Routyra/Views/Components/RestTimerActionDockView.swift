//
//  RestTimerActionDockView.swift
//  Routyra
//
//  Action dock for rest timer controls in workout set cards.
//  Displays log button with REST badge and unified timer pill.
//

import SwiftUI

struct RestTimerActionDockView: View {
    // MARK: - Properties

    /// Whether combination mode is enabled (auto-start timer on log)
    let isCombinationMode: Bool

    /// Current rest time in seconds
    let restTimeSeconds: Int

    /// Callback when log button is tapped
    let onLog: () -> Bool
    /// Optional override for log button title (localization key)
    let logTitleKey: String?
    /// Optional override for log button icon
    let logIconName: String

    /// Callback when timer start is requested
    let onTimerStart: () -> Void

    /// Callback when timer cancel is requested
    let onTimerCancel: () -> Void

    /// Callback when rest time is changed
    let onRestTimeChange: (Int) -> Void

    /// Reference to rest timer manager for state
    @ObservedObject var timerManager: RestTimerManager

    // MARK: - State

    @State private var showRestTimePicker = false
    @State private var editingRestTime: Int = 0
    @State private var logSuccessPulse = false
    @State private var hapticTrigger = 0

    // MARK: - Init

    init(
        isCombinationMode: Bool,
        restTimeSeconds: Int,
        onLog: @escaping () -> Bool,
        onTimerStart: @escaping () -> Void,
        onTimerCancel: @escaping () -> Void,
        onRestTimeChange: @escaping (Int) -> Void,
        timerManager: RestTimerManager,
        logTitleKey: String? = nil,
        logIconName: String = "checkmark"
    ) {
        self.isCombinationMode = isCombinationMode
        self.restTimeSeconds = restTimeSeconds
        self.onLog = onLog
        self.onTimerStart = onTimerStart
        self.onTimerCancel = onTimerCancel
        self.onRestTimeChange = onRestTimeChange
        self.timerManager = timerManager
        self.logTitleKey = logTitleKey
        self.logIconName = logIconName
    }

    // MARK: - Computed Properties

    private var formattedRestTime: String {
        let mins = restTimeSeconds / 60
        let secs = restTimeSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var isTimerRunning: Bool {
        timerManager.isRunning
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            // Row A: Log Button
            logButton

            // Row B: REST Timer Pill
            restTimerPill
        }
        .sheet(isPresented: $showRestTimePicker) {
            RestTimePickerSheet(restTimeSeconds: $editingRestTime)
                .onDisappear {
                    if editingRestTime != restTimeSeconds {
                        onRestTimeChange(editingRestTime)
                    }
                }
        }
    }

    // MARK: - Log Button (Row A)

    private var logButton: some View {
        let titleKey = logTitleKey ?? (isCombinationMode ? "rest_timer_log_and_start" : "rest_timer_log_set")
        return Button(action: {
            let success = onLog()
            if success {
                withAnimation(.easeInOut(duration: 0.15)) {
                    logSuccessPulse = true
                }
                hapticTrigger += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        logSuccessPulse = false
                    }
                }
            }
        }) {
            HStack(spacing: 0) {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: logIconName)
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.tr(titleKey))
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.accentBlue)
            .cornerRadius(12)
            .scaleEffect(logSuccessPulse ? 0.97 : 1.0)
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    // MARK: - REST Timer Pill (Row B)

    private var restTimerPill: some View {
        HStack(spacing: 0) {
            // Left: REST label
            Text("rest_timer_label")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isTimerRunning ? AppColors.accentBlue : AppColors.textSecondary)
                .padding(.leading, 16)

            Spacer()

            // Center: Time display (tappable for picker)
            timeDisplayButton

            Spacer()

            // Right: Action button (play/cancel)
            rightActionButton
                .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isTimerRunning ? AppColors.accentBlue.opacity(0.12) : AppColors.background)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTimerRunning ? AppColors.accentBlue.opacity(0.3) : AppColors.cardBackground.opacity(0.5), lineWidth: 1)
        )
    }

    private var timeDisplayButton: some View {
        Button(action: {
            guard !isTimerRunning else { return }
            editingRestTime = restTimeSeconds
            showRestTimePicker = true
        }) {
            HStack(spacing: 6) {
                if isTimerRunning {
                    // Running: show remaining
                    Text("rest_timer_remaining")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    Text(timerManager.formattedRemaining)
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundColor(AppColors.accentBlue)
                } else {
                    // Not running: show editable time
                    Text(formattedRestTime)
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundColor(restTimeSeconds > 0 ? AppColors.textPrimary : AppColors.textMuted)

                    if restTimeSeconds > 0 {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }
            .fixedSize()
        }
        .disabled(isTimerRunning)
    }

    @ViewBuilder
    private var rightActionButton: some View {
        if isTimerRunning {
            // Cancel button
            Button(action: onTimerCancel) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.textMuted.opacity(0.2))
                    .clipShape(Circle())
            }
        } else if !isCombinationMode && restTimeSeconds > 0 {
            // Start button (separation mode only)
            Button(action: onTimerStart) {
                Image(systemName: "play.fill")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)
                    .frame(width: 36, height: 36)
                    .background(AppColors.accentBlue.opacity(0.15))
                    .clipShape(Circle())
            }
        } else {
            // Placeholder for layout consistency
            Color.clear
                .frame(width: 36, height: 36)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var timerManager = RestTimerManager.shared

        var body: some View {
            VStack(spacing: 24) {
                // Separation mode
                VStack(alignment: .leading, spacing: 4) {
                    Text("Separation Mode")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                    RestTimerActionDockView(
                        isCombinationMode: false,
                        restTimeSeconds: 90,
                        onLog: { true },
                        onTimerStart: { _ = timerManager.start(duration: 90) },
                        onTimerCancel: { timerManager.cancel() },
                        onRestTimeChange: { _ in },
                        timerManager: timerManager
                    )
                }

                // Combination mode
                VStack(alignment: .leading, spacing: 4) {
                    Text("Combination Mode")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                    RestTimerActionDockView(
                        isCombinationMode: true,
                        restTimeSeconds: 120,
                        onLog: { true },
                        onTimerStart: {},
                        onTimerCancel: { timerManager.cancel() },
                        onRestTimeChange: { _ in },
                        timerManager: timerManager
                    )
                }

                // No rest time
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Rest Time")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                    RestTimerActionDockView(
                        isCombinationMode: false,
                        restTimeSeconds: 0,
                        onLog: { true },
                        onTimerStart: {},
                        onTimerCancel: {},
                        onRestTimeChange: { _ in },
                        timerManager: timerManager
                    )
                }
            }
            .padding()
            .background(AppColors.cardBackground)
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
