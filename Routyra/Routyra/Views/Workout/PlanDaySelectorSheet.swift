//
//  PlanDaySelectorSheet.swift
//  Routyra
//
//  Card overlay for selecting which plan day to use.
//  Shown when tapping "Day 1/3" in the workout header.
//

import SwiftUI
import SwiftData

struct PlanDaySelectorCardView: View {
    let planName: String
    let cycleName: String?          // nil if not in cycle mode
    let cyclePosition: String?      // "1/2" format
    let days: [PlanDay]
    let currentDayIndex: Int        // 1-indexed
    let canSwitchDay: Bool
    let onSelect: (Int) -> Void     // Called with dayIndex when day selected
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.tr("day_selector_title"))
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text(L10n.tr("done"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Plan info label (non-interactive)
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)

                Text(planName)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let cycleName = cycleName, let pos = cyclePosition {
                    Text("・")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                    Text("\(cycleName) (\(pos))")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Day list
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let isSelected = day.dayIndex == currentDayIndex

                    Button {
                        if canSwitchDay && !isSelected {
                            onSelect(day.dayIndex)
                        }
                    } label: {
                        HStack {
                            Text("Day \(day.dayIndex)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(canSwitchDay ? AppColors.textPrimary : AppColors.textMuted)

                            if let name = day.name, !name.isEmpty {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accentBlue)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .disabled(!canSwitchDay || isSelected)
                    .opacity(canSwitchDay ? 1.0 : 0.5)

                    // Divider (except for last item)
                    if index < days.count - 1 {
                        Divider()
                            .background(AppColors.textMuted.opacity(0.3))
                            .padding(.leading, 16)
                    }
                }
            }
            .background(AppColors.background)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()

        Color.black.opacity(0.5)
            .ignoresSafeArea()

        PlanDaySelectorCardViewPreview()
    }
    .preferredColorScheme(.dark)
}

private struct PlanDaySelectorCardViewPreview: View {
    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: PlanDay.self,
            configurations: config
        )

        // Create sample days
        let day1 = PlanDay(dayIndex: 1)
        day1.name = "Push"
        let day2 = PlanDay(dayIndex: 2)
        day2.name = "Pull"
        let day3 = PlanDay(dayIndex: 3)
        day3.name = "Legs"

        return PlanDaySelectorCardView(
            planName: "新しいトレーニングプラン",
            cycleName: nil,
            cyclePosition: nil,
            days: [day1, day2, day3],
            currentDayIndex: 1,
            canSwitchDay: true,
            onSelect: { _ in },
            onDismiss: {}
        )
        .modelContainer(container)
    }
}
