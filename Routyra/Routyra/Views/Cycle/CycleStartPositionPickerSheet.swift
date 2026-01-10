//
//  CycleStartPositionPickerSheet.swift
//  Routyra
//
//  Sheet for selecting which plan and day to start from in a cycle.
//

import SwiftUI
import SwiftData

struct CycleStartPositionPickerSheet: View {
    let cycle: PlanCycle
    @Binding var selectedPlanIndex: Int
    @Binding var selectedDayIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var sortedItems: [PlanCycleItem] {
        cycle.sortedItems
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(sortedItems.enumerated()), id: \.element.id) { planIdx, item in
                    let plan = loadPlan(for: item)

                    if let plan = plan {
                        Section {
                            ForEach(Array(plan.sortedDays.enumerated()), id: \.element.id) { dayIdx, day in
                                Button {
                                    selectedPlanIndex = planIdx
                                    selectedDayIndex = dayIdx
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(L10n.tr("cycle_start_day_label", dayIdx + 1))
                                                .font(.headline)
                                                .foregroundColor(AppColors.textPrimary)

                                            if let name = day.name, !name.isEmpty {
                                                Text(name)
                                                    .font(.caption)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        }

                                        Spacer()

                                        if selectedPlanIndex == planIdx && selectedDayIndex == dayIdx {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(AppColors.accentBlue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(L10n.tr("cycle_start_plan_label", planIdx + 1, plan.name.isEmpty ? L10n.tr("new_plan") : plan.name))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.tr("cycle_start_position_picker_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadPlan(for item: PlanCycleItem) -> WorkoutPlan? {
        if item.plan == nil {
            item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
        }
        return item.plan
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: PlanCycle.self, PlanCycleItem.self, WorkoutPlan.self, PlanDay.self,
        configurations: config
    )

    let cycle = PlanCycle(profileId: UUID(), name: "PPL Cycle")
    container.mainContext.insert(cycle)

    return CycleStartPositionPickerSheet(
        cycle: cycle,
        selectedPlanIndex: .constant(0),
        selectedDayIndex: .constant(0)
    )
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
