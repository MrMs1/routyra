//
//  StartTimingSection.swift
//  Routyra
//
//  Shared UI section for selecting plan/cycle start timing (today or scheduled date).
//

import SwiftUI

struct StartTimingSection: View {
    @Binding var selectedTiming: PlanStartTiming
    @Binding var scheduledStartDate: Date

    let todayHasWorkoutData: Bool

    var body: some View {
        VStack(spacing: 12) {
            Picker(L10n.tr("plan_start_mode_label"), selection: $selectedTiming) {
                Text(L10n.tr("plan_start_timing_today")).tag(PlanStartTiming.today)
                Text(L10n.tr("plan_start_timing_scheduled")).tag(PlanStartTiming.scheduled)
            }
            .pickerStyle(.segmented)

            if todayHasWorkoutData && selectedTiming != .scheduled {
                Text(L10n.tr("plan_start_warning_replace_today"))
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
            }

            if selectedTiming == .scheduled {
                HStack {
                    DatePicker(
                        L10n.tr("plan_start_date_label"),
                        selection: $scheduledStartDate,
                        in: DateUtilities.today...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .cornerRadius(10)
            }
        }
    }
}

