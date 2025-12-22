//
//  DayContextView.swift
//  Routyra
//
//  Displays the current day context with stepper controls for day navigation.
//  Used in WorkoutView to show and change the current plan day.
//

import SwiftUI

struct DayContextView: View {
    let currentDayIndex: Int
    let totalDays: Int
    let dayName: String?
    let canChangeDay: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    var onTapPlanLabel: (() -> Void)? = nil

    /// Full display label: "Day 2 / 6 ・ Push" or "Day 2 / 6" if no name
    private var fullDayLabel: String {
        let dayProgress = L10n.tr("day_progress", currentDayIndex, totalDays)
        if let name = dayName, !name.isEmpty {
            return "\(dayProgress) ・ \(name)"
        }
        return dayProgress
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // "プラン" label to clarify this is plan day switching (tappable if handler provided)
                if let tapAction = onTapPlanLabel {
                    Button {
                        tapAction()
                    } label: {
                        HStack(spacing: 4) {
                            Text(L10n.tr("day_context_plan_label"))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.accentBlue)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppColors.accentBlue.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(L10n.tr("day_context_plan_label"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Day info with stepper
                HStack(spacing: 6) {
                    // Previous button
                    if canChangeDay {
                        Button {
                            onPrevious()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.accentBlue)
                                .frame(width: 26, height: 26)
                                .background(AppColors.accentBlue.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Day label (single line: "Day 2 / 6 ・ Push")
                    Text(fullDayLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    // Next button
                    if canChangeDay {
                        Button {
                            onNext()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.accentBlue)
                                .frame(width: 26, height: 26)
                                .background(AppColors.accentBlue.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Status badge
                if !canChangeDay {
                    Text(L10n.tr("day_started_badge"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.textMuted.opacity(0.2))
                        .foregroundColor(AppColors.textSecondary)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        // Can change day with full name + tap handler
        DayContextView(
            currentDayIndex: 2,
            totalDays: 6,
            dayName: "Push（胸/肩）",
            canChangeDay: true,
            onPrevious: {},
            onNext: {},
            onTapPlanLabel: {}
        )

        Divider()

        // Cannot change day (started)
        DayContextView(
            currentDayIndex: 3,
            totalDays: 6,
            dayName: "Pull（背中/二頭）",
            canChangeDay: false,
            onPrevious: {},
            onNext: {},
            onTapPlanLabel: {}
        )

        Divider()

        // No day name, no tap handler
        DayContextView(
            currentDayIndex: 1,
            totalDays: 4,
            dayName: nil,
            canChangeDay: true,
            onPrevious: {},
            onNext: {}
        )

        Spacer()
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
