//
//  WeeklyActivityStripView.swift
//  Routyra
//

import SwiftUI

struct WeeklyActivityStripView: View {
    let dayProgress: [Int: Double]
    let selectedDayIndex: Int
    let onDayTap: (Int) -> Void

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let barWidth: CGFloat = 14
    private let baseBarHeight: CGFloat = 32
    private let selectedBarHeight: CGFloat = 38

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 6) {
                    ProgressBar(
                        progress: dayProgress[index] ?? 0,
                        isSelected: index == selectedDayIndex,
                        isToday: index == todayIndex,
                        width: barWidth,
                        height: barHeight(for: index)
                    )

                    Text(weekdays[index])
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(labelColor(for: index))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onDayTap(index)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func barHeight(for index: Int) -> CGFloat {
        index == selectedDayIndex ? selectedBarHeight : baseBarHeight
    }

    private func labelColor(for index: Int) -> Color {
        index == selectedDayIndex ? AppColors.textSecondary : AppColors.textMuted
    }
}

struct ProgressBar: View {
    let progress: Double
    let isSelected: Bool
    let isToday: Bool
    let width: CGFloat
    let height: CGFloat

    private var backgroundColor: Color {
        if isSelected {
            return AppColors.dotEmpty.opacity(0.6)
        } else if isToday {
            return AppColors.dotEmpty.opacity(0.5)
        } else {
            return AppColors.dotEmpty.opacity(0.3)
        }
    }

    private var fillColor: Color {
        if isSelected {
            return AppColors.accentBlue
        } else if isToday {
            return AppColors.accentBlue.opacity(0.8)
        } else {
            return AppColors.mutedBlue
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(backgroundColor)
                .frame(width: width, height: height)

            if progress > 0 {
                Capsule()
                    .fill(fillColor)
                    .frame(width: width, height: max(width, height * CGFloat(min(progress, 1.0))))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WeeklyActivityStripView(
            dayProgress: [0: 1.0, 1: 0.6, 2: 0.2, 3: 0, 4: 0.8, 5: 0, 6: 0.4],
            selectedDayIndex: 0,
            onDayTap: { _ in }
        )

        WeeklyActivityStripView(
            dayProgress: [0: 1.0, 1: 1.0, 2: 1.0, 3: 0.5, 4: 0, 5: 0, 6: 0],
            selectedDayIndex: 3,
            onDayTap: { _ in }
        )

        WeeklyActivityStripView(
            dayProgress: [:],
            selectedDayIndex: 6,
            onDayTap: { _ in }
        )
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
