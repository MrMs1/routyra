//
//  PlanStartDayPickerSheet.swift
//  Routyra
//
//  Sheet for selecting which day to start when activating a plan.
//

import SwiftUI

struct PlanStartDayPickerSheet: View {
    let days: [PlanDay]
    @Binding var selectedDayIndex: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let dayIndex = index + 1
                    Button {
                        selectedDayIndex = dayIndex
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("day_label", dayIndex))
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)

                                if let name = day.name, !name.isEmpty {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            Spacer()

                            if selectedDayIndex == dayIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accentBlue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle(L10n.tr("plan_start_day_picker_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    let days = (1...4).map { index in
        let day = PlanDay(dayIndex: index)
        if index == 2 {
            day.name = "Push"
        } else if index == 3 {
            day.name = "Pull"
        }
        return day
    }

    PlanStartDayPickerSheet(
        days: days,
        selectedDayIndex: .constant(1)
    )
    .preferredColorScheme(.dark)
}
