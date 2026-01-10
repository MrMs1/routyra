//
//  WeeklyActivityStripView.swift
//  Routyra
//
//  Week strip showing weekday + date + workout indicator.
//  Displays Monday-Sunday with selection and today states.
//

import SwiftUI

// MARK: - Workout Day State

enum WorkoutDayState {
    case none       // No workout
    case incomplete // Started but not finished
    case complete   // All exercises completed
}

// MARK: - Weekly Activity Strip View

struct WeeklyActivityStripView: View {
    let weekStart: Date                        // Week start date (Monday)
    let selectedDayIndex: Int                  // Selected day (0-6, Monday = 0)
    let workoutStates: [Int: WorkoutDayState]  // dayIndex -> state
    let onDayTap: (Int) -> Void

    private var todayIndex: Int {
        DateUtilities.weekdayIndex(for: Date())
    }

    private var weekdays: [String] {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else {
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
        // Shift Sunday (index 0) to end: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
        return Array(symbols[1...]) + [symbols[0]]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                DayCell(
                    weekday: weekdays[index],
                    dayNumber: dayNumber(for: index),
                    isSelected: index == selectedDayIndex,
                    isToday: index == todayIndex,
                    workoutState: workoutStates[index] ?? .none,
                    dayIndex: index
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onDayTap(index)
                }

                if index < 6 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func dayNumber(for index: Int) -> Int {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: index, to: weekStart) else {
            return 1
        }
        return calendar.component(.day, from: date)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let weekday: String           // "月", "Mon"
    let dayNumber: Int            // 23
    let isSelected: Bool
    let isToday: Bool
    let workoutState: WorkoutDayState
    let dayIndex: Int             // 0-6 (Sat=5, Sun=6)

    private var weekdayColor: Color {
        switch dayIndex {
        case 5: return AppColors.weekendSaturday
        case 6: return AppColors.weekendSunday
        default: return AppColors.textSecondary
        }
    }

    /// Border style: selected = strong, today (non-selected) = weak
    private var borderStyle: (color: Color, lineWidth: CGFloat)? {
        if isSelected {
            // Selected: strong border
            return (AppColors.accentBlue.opacity(0.8), 2)
        } else if isToday {
            // Today (non-selected): weak border
            return (AppColors.accentBlue.opacity(0.35), 1)
        }
        return nil
    }

    /// Dot color based on workout state
    private var dotColor: Color? {
        switch workoutState {
        case .complete: return AppColors.accentBlue
        case .incomplete: return AppColors.textSecondary
        case .none: return nil
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // Weekday label
            Text(weekday)
                .font(.caption2)
                .foregroundColor(weekdayColor)

            // Date number + selection background
            Text("\(dayNumber)")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.cardBackground.opacity(0.5))
                        : nil
                )

            // Workout indicator dot (3 states)
            Circle()
                .fill(dotColor ?? Color.clear)
                .frame(width: 4, height: 4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        // Border (selected or today)
        .overlay(
            Group {
                if let style = borderStyle {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style.color, lineWidth: style.lineWidth)
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let weekStart = DateUtilities.startOfWeekMonday(containing: today) ?? today
    let todayIndex = DateUtilities.weekdayIndex(for: today)

    // Sample workout states
    let workoutStates: [Int: WorkoutDayState] = [
        todayIndex: .incomplete,
        max(0, todayIndex - 1): .complete,
        max(0, todayIndex - 2): .complete
    ]

    VStack(spacing: 20) {
        // Today selected
        WeeklyActivityStripView(
            weekStart: weekStart,
            selectedDayIndex: todayIndex,
            workoutStates: workoutStates,
            onDayTap: { _ in }
        )

        // Different day selected (showing today border)
        WeeklyActivityStripView(
            weekStart: weekStart,
            selectedDayIndex: 0,
            workoutStates: workoutStates,
            onDayTap: { _ in }
        )

        // Empty workouts
        WeeklyActivityStripView(
            weekStart: weekStart,
            selectedDayIndex: 3,
            workoutStates: [:],
            onDayTap: { _ in }
        )
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
