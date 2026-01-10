//
//  WorkoutHeaderView.swift
//  Routyra
//

import SwiftUI

// MARK: - Day Display Info

struct DayDisplayInfo {
    let currentDayIndex: Int  // 1-indexed
    let totalDays: Int
    let canSwitchDay: Bool
}

// MARK: - Workout Header View

struct WorkoutHeaderView: View {
    let date: Date              // Selected date
    let isViewingToday: Bool
    let dayInfo: DayDisplayInfo?  // nil if no active plan
    let onTodayTap: () -> Void    // Navigate to today
    let onDayTap: () -> Void      // Open day selector sheet

    private var dateFormatter: DateFormatter {
        Formatters.shortDate
    }

    @ViewBuilder
    private var rightButton: some View {
        if isViewingToday {
            // Day display (only if multi-day plan)
            if let dayInfo = dayInfo, dayInfo.totalDays > 1 {
                if dayInfo.canSwitchDay {
                    // Tappable: capsule button with chevron
                    Button(action: onDayTap) {
                        HStack(spacing: 4) {
                            Text(L10n.tr("day_compact", dayInfo.currentDayIndex, dayInfo.totalDays))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.subheadline)
                        .foregroundColor(AppColors.accentBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(AppColors.accentBlue.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    // Not tappable: plain text (still tappable to view sheet, but styled as non-interactive)
                    Button(action: onDayTap) {
                        Text(L10n.tr("day_compact", dayInfo.currentDayIndex, dayInfo.totalDays))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No multi-day plan: invisible placeholder
                Color.clear
            }
        } else {
            // Today button
            Button(action: onTodayTap) {
                HStack(spacing: 4) {
                    Text(L10n.tr("today"))
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
                .foregroundColor(AppColors.accentBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        ZStack {
            Text("workout")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            HStack {
                // Left: Selected date (no tap action)
                Text(dateFormatter.string(from: date))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Right: Day display or Today button (fixed height for consistency)
                rightButton
                    .frame(height: 28)  // Fixed height for all states
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        // Viewing today with multi-day plan (can switch)
        WorkoutHeaderView(
            date: Date(),
            isViewingToday: true,
            dayInfo: DayDisplayInfo(currentDayIndex: 1, totalDays: 3, canSwitchDay: true),
            onTodayTap: {},
            onDayTap: {}
        )

        // Viewing today with multi-day plan (cannot switch - started)
        WorkoutHeaderView(
            date: Date(),
            isViewingToday: true,
            dayInfo: DayDisplayInfo(currentDayIndex: 2, totalDays: 3, canSwitchDay: false),
            onTodayTap: {},
            onDayTap: {}
        )

        // Viewing today with 1-day plan (no Day button)
        WorkoutHeaderView(
            date: Date(),
            isViewingToday: true,
            dayInfo: DayDisplayInfo(currentDayIndex: 1, totalDays: 1, canSwitchDay: true),
            onTodayTap: {},
            onDayTap: {}
        )

        // Viewing today with no plan
        WorkoutHeaderView(
            date: Date(),
            isViewingToday: true,
            dayInfo: nil,
            onTodayTap: {},
            onDayTap: {}
        )

        // Viewing another day (shows Today button)
        WorkoutHeaderView(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            isViewingToday: false,
            dayInfo: DayDisplayInfo(currentDayIndex: 1, totalDays: 3, canSwitchDay: false),
            onTodayTap: {},
            onDayTap: {}
        )
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
