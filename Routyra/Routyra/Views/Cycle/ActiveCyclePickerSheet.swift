//
//  ActiveCyclePickerSheet.swift
//  Routyra
//
//  Sheet for selecting the active cycle with detailed info.
//

import SwiftUI

struct ActiveCyclePickerSheet: View {
    let cycles: [PlanCycle]
    let activeCycleId: UUID?
    let onSelect: (PlanCycle?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Cycles section
                if !cycles.isEmpty {
                    Section {
                        ForEach(cycles, id: \.id) { cycle in
                            Button {
                                onSelect(cycle)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cycle.name.isEmpty ? L10n.tr("cycle_new_title") : cycle.name)
                                            .font(.body)
                                            .foregroundColor(AppColors.textPrimary)

                                        Text(L10n.tr("cycle_plan_count", cycle.planCount))
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    if cycle.id == activeCycleId {
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
                        Text(L10n.tr("cycle_list_title"))
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

                            if activeCycleId == nil {
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
            .navigationTitle(L10n.tr("active_cycle"))
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
    ActiveCyclePickerSheet(
        cycles: [],
        activeCycleId: nil
    ) { _ in }
    .preferredColorScheme(.dark)
}
