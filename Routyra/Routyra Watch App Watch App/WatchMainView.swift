//
//  WatchMainView.swift
//  Routyra Watch App Watch App
//
//  Main coordinator view for the Watch app.
//  Shows current set, timer, alarm, or completion screen.
//

import SwiftUI

// MARK: - Watch Screen State

enum WatchScreenState {
    case loading        // Waiting for data from iPhone
    case noPlan         // No routine applied
    case currentSet     // Showing current set to complete
    case confirmTimer   // Asking if user wants to start timer (non-combination mode)
    case timer          // Rest timer running
    case alarm          // Timer completed, alarm active
    case completed      // All sets completed
}

// MARK: - Watch Main View

struct WatchMainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @StateObject private var timerManager = WatchRestTimerManager.shared
    @StateObject private var themeManager = WatchThemeManager.shared

    // MARK: - State

    /// Whether to show the timer confirmation dialog (for non-combination mode)
    @State private var showingTimerConfirmation = false
    /// Pending rest time for confirmation dialog
    @State private var pendingRestTime: Int = 0

    // MARK: - Computed Properties

    private var workoutData: WatchWorkoutData? {
        connectivityManager.workoutData
    }

    // MARK: - Next Item (Group-first)

    private func completedSetsCount(in exercise: WatchExerciseData) -> Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    private func roundsCompleted(in group: WatchExerciseGroupData) -> Int {
        guard group.setCount > 0 else { return 0 }
        guard !group.exercises.isEmpty else { return 0 }
        let minCompleted = group.exercises.map { completedSetsCount(in: $0) }.min() ?? 0
        return min(minCompleted, group.setCount)
    }

    private func activeRound(in group: WatchExerciseGroupData) -> Int {
        let completed = roundsCompleted(in: group)
        return min(completed + 1, max(group.setCount, 1))
    }

    private func isAllRoundsComplete(_ group: WatchExerciseGroupData) -> Bool {
        roundsCompleted(in: group) >= group.setCount
    }

    private func isRoundComplete(_ group: WatchExerciseGroupData, round: Int) -> Bool {
        guard round > 0 else { return true }
        return group.exercises.allSatisfy { completedSetsCount(in: $0) >= round }
    }

    private var nextIncompleteGroup: WatchExerciseGroupData? {
        guard let data = workoutData else { return nil }
        return data.exerciseGroups
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { !isAllRoundsComplete($0) }
    }

    private var nextIncompleteUngroupedSet: (exercise: WatchExerciseData, set: WatchSetData, setNumber: Int, totalSets: Int)? {
        guard let data = workoutData else { return nil }

        for exercise in data.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let sortedSets = exercise.sets.sorted { $0.setIndex < $1.setIndex }
            for (index, set) in sortedSets.enumerated() {
                if !set.isCompleted {
                    return (exercise, set, index + 1, sortedSets.count)
                }
            }
        }
        return nil
    }

    private enum NextIncompleteItem {
        case group(WatchExerciseGroupData)
        case ungrouped(exercise: WatchExerciseData, set: WatchSetData, setNumber: Int, totalSets: Int)
    }

    private var nextIncompleteItem: NextIncompleteItem? {
        let group = nextIncompleteGroup
        let ungrouped = nextIncompleteUngroupedSet

        switch (group, ungrouped) {
        case (nil, nil):
            return nil
        case (let group?, nil):
            return .group(group)
        case (nil, let ungrouped?):
            return .ungrouped(
                exercise: ungrouped.exercise,
                set: ungrouped.set,
                setNumber: ungrouped.setNumber,
                totalSets: ungrouped.totalSets
            )
        case (let group?, let ungrouped?):
            let groupIndex = group.orderIndex
            let exerciseIndex = ungrouped.exercise.orderIndex
            if groupIndex < exerciseIndex {
                return .group(group)
            }
            return .ungrouped(
                exercise: ungrouped.exercise,
                set: ungrouped.set,
                setNumber: ungrouped.setNumber,
                totalSets: ungrouped.totalSets
            )
        }
    }

    private var screenState: WatchScreenState {
        // Timer confirmation takes priority
        if showingTimerConfirmation {
            return .confirmTimer
        }

        switch timerManager.state {
        case .running:
            return .timer
        case .alarm:
            return .alarm
        case .idle:
            guard let data = workoutData else {
                return .loading
            }
            // Allow both routine and non-routine workouts.
            // Show "no workout" only when there's nothing to record.
            if data.exercises.isEmpty && data.exerciseGroups.isEmpty {
                return .noPlan
            }
            if nextIncompleteItem == nil {
                return .completed
            }
            return .currentSet
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            themeManager.background
                .ignoresSafeArea()

            Group {
                switch screenState {
                case .loading:
                    LoadingView(isReachable: connectivityManager.isReachable, themeManager: themeManager)

                case .noPlan:
                    NoPlanView(themeManager: themeManager)

                case .currentSet:
                    if let item = nextIncompleteItem {
                        switch item {
                        case .group(let group):
                            let round = activeRound(in: group)
                            GroupRoundView(
                                group: group,
                                activeRound: round,
                                themeManager: themeManager,
                                onLogRound: {
                                    let setIds = setIdsToLogForRound(group: group, round: round)
                                    guard !setIds.isEmpty else { return }
                                    for setId in setIds {
                                        recordSet(setId: setId)
                                    }
                                    // Group spec: no rest after the final round.
                                    if round < group.setCount {
                                        startRestTimerIfNeeded(restTimeSeconds: group.roundRestSeconds)
                                    }
                                }
                            )
                        case .ungrouped(let exercise, let set, let setNumber, let totalSets):
                            CurrentSetView(
                                exercise: exercise,
                                set: set,
                                setNumber: setNumber,
                                totalSets: totalSets,
                                themeManager: themeManager,
                                onComplete: {
                                    recordSet(setId: set.id)
                                    startRestTimerIfNeeded(restTimeSeconds: set.restTimeSeconds)
                                }
                            )
                        }
                    }

                case .confirmTimer:
                    TimerConfirmationView(
                        restTime: pendingRestTime,
                        themeManager: themeManager,
                        onStartTimer: {
                            showingTimerConfirmation = false
                            timerManager.start(duration: pendingRestTime)
                        },
                        onSkip: {
                            showingTimerConfirmation = false
                        }
                    )

                case .timer:
                    TimerView(
                        timerManager: timerManager,
                        themeManager: themeManager,
                        onSkip: { timerManager.skip() }
                    )

                case .alarm:
                    AlarmView(
                        themeManager: themeManager,
                        onDismiss: { timerManager.dismissAlarm() }
                    )

                case .completed:
                    CompletionView(themeManager: themeManager)
                }
            }
        }
        .onAppear {
            connectivityManager.requestSync()
            themeManager.refreshTheme()
        }
        .onChange(of: connectivityManager.lastSyncDate) { _, _ in
            // Refresh theme when any payload arrives (theme is stored in App Groups).
            themeManager.refreshTheme()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                timerManager.handleEnterBackground()
            case .active:
                themeManager.refreshTheme()
                timerManager.handleEnterForeground()
            default:
                break
            }
        }
        .onChange(of: timerManager.state) { _, _ in
            // Refresh theme when transitioning between main screens (idle ↔ timer ↔ alarm).
            // This helps pick up theme changes made on iPhone while Watch app stays active.
            themeManager.refreshTheme()
        }
    }

    // MARK: - Actions

    private func setIdsToLogForRound(group: WatchExerciseGroupData, round: Int) -> [UUID] {
        let index = max(round - 1, 0)
        let sortedExercises = group.exercises.sorted { ($0.groupOrderIndex ?? 0) < ($1.groupOrderIndex ?? 0) }
        var ids: [UUID] = []
        ids.reserveCapacity(sortedExercises.count)

        for exercise in sortedExercises {
            let sortedSets = exercise.sets.sorted { $0.setIndex < $1.setIndex }
            guard index < sortedSets.count else { continue }
            let set = sortedSets[index]
            if !set.isCompleted {
                ids.append(set.id)
            }
        }
        return ids
    }

    private func recordSet(setId: UUID) {
        // Update local state immediately
        connectivityManager.markSetCompleted(setId: setId)

        // Send completion to iPhone
        connectivityManager.sendSetCompletion(setId: setId)
    }

    private func startRestTimerIfNeeded(restTimeSeconds: Int?) {
        // Calculate effective rest time
        let effectiveRestTime = restTimeSeconds ?? workoutData?.defaultRestTimeSeconds ?? 0

        // Check if combination mode is enabled
        let combineMode = workoutData?.combineRecordAndTimerStart ?? false

        if effectiveRestTime > 0 {
            if combineMode {
                // Auto-start rest timer in combination mode
                timerManager.start(duration: effectiveRestTime)
            } else {
                // Show confirmation dialog in non-combination mode
                pendingRestTime = effectiveRestTime
                showingTimerConfirmation = true
            }
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    let isReachable: Bool
    @ObservedObject var themeManager: WatchThemeManager

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(themeManager.accentBlue)

            Text(isReachable ? "同期中..." : "iPhoneに接続中...")
                .font(.footnote)
                .foregroundColor(themeManager.textSecondary)
        }
        .padding()
    }
}

// MARK: - No Plan View

private struct NoPlanView: View {
    @ObservedObject var themeManager: WatchThemeManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 32))
                .foregroundColor(themeManager.textSecondary)

            Text("トレーニングプランを適用してください")
                .font(.footnote)
                .foregroundColor(themeManager.textSecondary)
                .multilineTextAlignment(.center)

            Text("iPhoneアプリで設定できます")
                .font(.caption2)
                .foregroundColor(themeManager.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Current Set View

private struct CurrentSetView: View {
    let exercise: WatchExerciseData
    let set: WatchSetData
    let setNumber: Int
    let totalSets: Int
    @ObservedObject var themeManager: WatchThemeManager
    let onComplete: () -> Void

    private var setDescription: String {
        switch exercise.metricType {
        case "weightReps":
            let weight = set.weight ?? 0
            let reps = set.reps ?? 0
            let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", weight)
                : String(format: "%.1f", weight)
            return "\(weightStr)kg × \(reps)"
        case "bodyweightReps":
            let reps = set.reps ?? 0
            return "× \(reps)"
        case "timeDistance":
            if let duration = set.durationSeconds {
                let mins = duration / 60
                let secs = duration % 60
                return String(format: "%d:%02d", mins, secs)
            }
            return "--:--"
        case "completion":
            return "Complete"
        default:
            return "--"
        }
    }

    private var bodyPartColor: Color {
        themeManager.bodyPartColor(for: exercise.bodyPartCode)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Exercise name with body part color dot
            HStack(spacing: 6) {
                Circle()
                    .fill(bodyPartColor)
                    .frame(width: 8, height: 8)

                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(themeManager.textPrimary)
                    .lineLimit(2)
            }

            // Set info
            VStack(spacing: 4) {
                Text("セット \(setNumber)/\(totalSets)")
                    .font(.caption)
                    .foregroundColor(themeManager.textSecondary)

                Text(setDescription)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.textPrimary)
            }

            // Complete button
            Button(action: onComplete) {
                Text("記録")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.accentBlue)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Timer Confirmation View

private struct TimerConfirmationView: View {
    let restTime: Int
    @ObservedObject var themeManager: WatchThemeManager
    let onStartTimer: () -> Void
    let onSkip: () -> Void

    private var formattedTime: String {
        let mins = restTime / 60
        let secs = restTime % 60
        if mins > 0 {
            return secs > 0 ? "\(mins)分\(secs)秒" : "\(mins)分"
        }
        return "\(secs)秒"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(themeManager.accentBlue)

                Text("レストタイマー")
                    .font(.headline)
                    .foregroundColor(themeManager.textPrimary)
            }

            Text(formattedTime)
                .font(.title3)
                .foregroundColor(themeManager.textSecondary)

            // Start Timer button
            Button(action: onStartTimer) {
                Text("開始")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeManager.accentBlue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        // Keep skip always visible at the bottom
        .safeAreaInset(edge: .bottom) {
            Button(action: onSkip) {
                Text("スキップ")
                    .font(.footnote)
                    .foregroundColor(themeManager.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Timer View

private struct TimerView: View {
    @ObservedObject var timerManager: WatchRestTimerManager
    @ObservedObject var themeManager: WatchThemeManager
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Remaining time
            Text(timerManager.formattedRemaining)
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .foregroundColor(themeManager.textPrimary)
                .monospacedDigit()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.cardBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.accentBlue)
                        .frame(width: geometry.size.width * timerManager.progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
        }
        .padding()
        .safeAreaInset(edge: .bottom) {
            Button(action: onSkip) {
                Text("スキップ")
                    .font(.footnote)
                    .foregroundColor(themeManager.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Alarm View

private struct AlarmView: View {
    @ObservedObject var themeManager: WatchThemeManager
    let onDismiss: () -> Void

    @State private var crownValue: Double = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 40))
                .foregroundColor(themeManager.alertRed)

            Text("レスト終了！")
                .font(.headline)
                .foregroundColor(themeManager.textPrimary)

            Button(action: onDismiss) {
                Text("停止")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.accentBlue)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .focusable()
        .digitalCrownRotation($crownValue)
        .onChange(of: crownValue) { _, _ in
            onDismiss()
        }
    }
}

// MARK: - Completion View

private struct CompletionView: View {
    @ObservedObject var themeManager: WatchThemeManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(themeManager.successGreen)

            Text("ワークアウト完了")
                .font(.headline)
                .foregroundColor(themeManager.textPrimary)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    WatchMainView()
        .environmentObject(WatchConnectivityManager.shared)
}
