//
//  ActivePlanPickerSheet.swift
//  Routyra
//
//  Sheet for selecting the active workout plan with detailed info.
//

import SwiftUI

struct ActivePlanPickerSheet: View {
    let plans: [WorkoutPlan]
    let activePlanId: UUID?
    let onSelect: (WorkoutPlan?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Plans section
                if !plans.isEmpty {
                    Section {
                        ForEach(plans, id: \.id) { plan in
                            Button {
                                onSelect(plan)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.name.isEmpty ? L10n.tr("new_plan") : plan.name)
                                            .font(.body)
                                            .foregroundColor(AppColors.textPrimary)

                                        Text(L10n.tr("plan_summary_days_exercises", plan.dayCount, plan.totalExerciseCount))
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    if plan.id == activePlanId {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.accentBlue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(AppColors.cardBackground)
                        }
                    } header: {
                        Text(L10n.tr("plan_available_section"))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                // None option
                Section {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text(L10n.tr("none"))
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if activePlanId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accentBlue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppColors.cardBackground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("select_active_plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ActivePlanPickerSheet(
        plans: [],
        activePlanId: nil
    ) { _ in }
    .preferredColorScheme(.dark)
}
