//
//  WorkoutExerciseGroupCardView.swift
//  Routyra
//
//  Group header card for exercise group display in workout view.
//  Shows group label, round progress, and rest time.
//  Structure is read-only (no dissolve/set count change).
//

import SwiftUI
import SwiftData

struct WorkoutExerciseGroupCardView: View {
    let group: WorkoutExerciseGroup
    let onUpdateRest: (Int?) -> Void
    var showsBackground: Bool = true
    var showsRestTimeButton: Bool = true

    @State private var showRestEditor = false
    @State private var editedRestMinutes: Int = 0
    @State private var editedRestSeconds: Int = 0

    var body: some View {
        Group {
            if showsBackground {
                headerContent
                    .background(AppColors.cardBackground)
                    .cornerRadius(10)
            } else {
                headerContent
            }
        }
        .sheet(isPresented: $showRestEditor) {
            WorkoutGroupRestEditorSheet(
                minutes: $editedRestMinutes,
                seconds: $editedRestSeconds,
                onSave: {
                    let total = editedRestMinutes * 60 + editedRestSeconds
                    onUpdateRest(total > 0 ? total : nil)
                }
            )
            .presentationDetents([.height(250)])
        }
    }

    // MARK: - Computed Properties

    private var headerContent: some View {
        HStack(spacing: 10) {
            // Group badge
            HStack(spacing: 4) {
                Image(systemName: "rectangle.stack")
                    .font(.caption)
                Text(group.displayName)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(progressColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(progressColor.opacity(0.15))
            .cornerRadius(6)

            // Completed checkmark (match single-exercise completion affordance)
            if group.isAllRoundsComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(progressColor)
            }

            Spacer()

            // Rest time (editable)
            if showsRestTimeButton {
                Button {
                    if let rest = group.roundRestSeconds {
                        editedRestMinutes = rest / 60
                        editedRestSeconds = rest % 60
                    } else {
                        editedRestMinutes = 1
                        editedRestSeconds = 30
                    }
                    showRestEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text(formatRestTime(group.roundRestSeconds))
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, showsBackground ? 12 : 0)
        .padding(.vertical, showsBackground ? 8 : 4)
    }

    private var progressColor: Color {
        switch group.progressState {
        case .notStarted:
            return AppColors.textMuted
        case .inProgress:
            return AppColors.textSecondary
        case .completed:
            return AppColors.accentBlue
        }
    }

    // MARK: - Helpers

    private func formatRestTime(_ seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else {
            return L10n.tr("none")
        }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        } else if mins > 0 {
            return "\(mins):00"
        } else {
            return "0:\(String(format: "%02d", secs))"
        }
    }
}

// MARK: - Rest Editor Sheet

private struct WorkoutGroupRestEditorSheet: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    VStack {
                        Picker("", selection: $minutes) {
                            ForEach(0...10, id: \.self) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text(L10n.tr("rest_time_minutes"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    VStack {
                        Picker("", selection: $seconds) {
                            ForEach(0...59, id: \.self) { sec in
                                Text("\(sec)").tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text(L10n.tr("rest_time_seconds"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("group_round_rest"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("save")) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Group Round Dots (Vertical)

struct GroupRoundDotsColumnView: View {
    let completedRounds: Int
    let totalRounds: Int
    let activeRound: Int
    let isAllRoundsComplete: Bool
    /// True when user is viewing a completed round (i.e. selectedRoundIndex < active round).
    /// Matches single-exercise behavior: do not emphasize the active (incomplete) round while viewing history.
    let isViewingCompletedRound: Bool
    let selectedRoundIndex: Int
    let onSelectRound: (Int) -> Void

    private let dotSize: CGFloat = 26
    private let dotSpacing: CGFloat = 8
    private let lineWidth: CGFloat = 2

    private var completedCount: Int {
        min(completedRounds, totalRounds)
    }

    private var activeIndex: Int? {
        guard totalRounds > 0, !isAllRoundsComplete else { return nil }
        return min(max(activeRound - 1, 0), totalRounds - 1)
    }

    private var lineSegmentCount: Int {
        if let activeIndex, completedCount > 0 {
            return activeIndex
        }
        return max(0, completedCount - 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if lineSegmentCount > 0 {
                let baseHeight = CGFloat(lineSegmentCount) * (dotSize + dotSpacing)
                let lineHeight = activeIndex != nil && completedCount > 0
                    ? baseHeight - dotSize / 2
                    : baseHeight

                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.dotFilled)
                    .frame(width: lineWidth)
                    .frame(height: lineHeight)
                    .offset(y: dotSize / 2)
            }

            VStack(spacing: dotSpacing) {
                ForEach(0..<max(totalRounds, 0), id: \.self) { index in
                    GroupRoundDotView(
                        index: index,
                        isCompleted: index < completedCount,
                        // Match SetDotsView: when a completed round is selected, don't visually "pull" attention
                        // to the current active round (prevents the uncompleted round from looking odd).
                        isActive: !isViewingCompletedRound && index == activeIndex,
                        isSelected: index == selectedRoundIndex,
                        dotSize: dotSize
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let maxSelectable = activeIndex ?? (totalRounds - 1)
                        guard index <= maxSelectable else { return }
                        onSelectRound(index)
                    }
                }
            }
        }
        .frame(width: dotSize)
    }
}

private struct GroupRoundDotView: View {
    let index: Int
    let isCompleted: Bool
    let isActive: Bool
    let isSelected: Bool
    let dotSize: CGFloat

    private var ringColor: Color {
        isCompleted ? AppColors.accentBlue : AppColors.textSecondary
    }

    private var numberColor: Color {
        isCompleted ? AppColors.accentBlue : AppColors.textPrimary
    }

    var body: some View {
        ZStack {
            // Show LARGE numbered circle ONLY for the selected round.
            // Active round should NOT look "selected" when viewing a completed round.
            if isSelected {
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: dotSize, height: dotSize)

                Circle()
                    .stroke(ringColor, lineWidth: 1.5)
                    .frame(width: dotSize, height: dotSize)

                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(numberColor)
            } else {
                // Small dot for non-selected rounds.
                // If this is the active round, emphasize subtly with a ring (no number).
                ZStack {
                    Circle()
                        .fill(isCompleted ? AppColors.dotFilled : AppColors.dotEmpty)
                        .frame(width: 10, height: 10)

                    if isActive {
                        Circle()
                            .stroke(AppColors.accentBlue.opacity(0.8), lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
        .frame(width: dotSize, height: dotSize)
    }
}
