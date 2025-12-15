//
//  CyclePlanPickerView.swift
//  Routyra
//
//  Picker for selecting a WorkoutPlan to add to a cycle.
//

import SwiftUI
import SwiftData

struct CyclePlanPickerView: View {
    let cycle: PlanCycle
    let onAdded: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]

    @State private var profile: LocalProfile?
    @State private var searchText: String = ""

    private var profilePlans: [WorkoutPlan] {
        guard let profileId = profile?.id else { return [] }
        return plans.filter { $0.profileId == profileId && !$0.isArchived }
    }

    private var filteredPlans: [WorkoutPlan] {
        if searchText.isEmpty {
            return profilePlans
        }
        return profilePlans.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var existingPlanIds: Set<UUID> {
        Set(cycle.items.map(\.planId))
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredPlans.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.textMuted)

                            Text("プランがありません")
                                .font(.headline)
                                .foregroundColor(AppColors.textSecondary)

                            Text("先にプランを作成してください")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filteredPlans) { plan in
                            PlanRowView(
                                plan: plan,
                                isAlreadyAdded: existingPlanIds.contains(plan.id),
                                onSelect: {
                                    addPlan(plan)
                                }
                            )
                        }
                    } header: {
                        Text("利用可能なプラン")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("プランを追加")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "プランを検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            }
        }
    }

    private func addPlan(_ plan: WorkoutPlan) {
        CycleService.addPlan(to: cycle, plan: plan, modelContext: modelContext)
        onAdded()
        dismiss()
    }
}

// MARK: - Plan Row View

private struct PlanRowView: View {
    let plan: WorkoutPlan
    let isAlreadyAdded: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            if !isAlreadyAdded {
                onSelect()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isAlreadyAdded ? AppColors.textMuted : AppColors.textPrimary)

                    Text("\(plan.dayCount)日間 / \(plan.totalExerciseCount)種目")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isAlreadyAdded {
                    Text("追加済み")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isAlreadyAdded)
    }
}

#Preview {
    let cycle = PlanCycle(profileId: UUID(), name: "Test Cycle")

    return CyclePlanPickerView(cycle: cycle, onAdded: {})
        .modelContainer(for: [
            LocalProfile.self,
            PlanCycle.self,
            PlanCycleItem.self,
            PlanCycleProgress.self,
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlannedSet.self
        ], inMemory: true)
        .preferredColorScheme(.dark)
}
