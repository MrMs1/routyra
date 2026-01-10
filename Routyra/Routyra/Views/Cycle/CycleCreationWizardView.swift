//
//  CycleCreationWizardView.swift
//  Routyra
//
//  Wizard for creating a new cycle.
//  Creates a cycle with default name immediately and shows plan picker.
//  Flow: Create cycle → Add plans → Complete
//

import SwiftUI
import SwiftData

struct CycleCreationWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profile: LocalProfile
    let onComplete: (PlanCycle) -> Void

    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var allPlans: [WorkoutPlan]

    @State private var draftCycle: PlanCycle?
    @State private var searchText: String = ""

    private var profilePlans: [WorkoutPlan] {
        allPlans.filter { $0.profileId == profile.id && !$0.isArchived }
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
        guard let cycle = draftCycle else { return [] }
        return Set(cycle.items.map(\.planId))
    }

    private var addedPlansCount: Int {
        draftCycle?.items.count ?? 0
    }

    var body: some View {
        NavigationStack {
            List {
                addedPlansSection
                availablePlansSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("cycle_new_title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: L10n.tr("plan_search_placeholder"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        cancelWizard()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("done")) {
                        completeWizard()
                    }
                    .fontWeight(.semibold)
                    .disabled(addedPlansCount == 0)
                }
            }
            .onAppear {
                createDraftCycle()
            }
        }
        .interactiveDismissDisabled(draftCycle != nil)
    }

    // MARK: - Added Plans Section

    @ViewBuilder
    private var addedPlansSection: some View {
        if addedPlansCount > 0, let cycle = draftCycle {
            Section {
                ForEach(cycle.sortedItems, id: \.id) { item in
                    AddedPlanRowView(
                        item: item,
                        modelContext: modelContext,
                        onRemove: { removePlan(item) }
                    )
                }
            } header: {
                Text(L10n.tr("cycle_plans_section"))
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }

    // MARK: - Available Plans Section

    @ViewBuilder
    private var availablePlansSection: some View {
        if filteredPlans.isEmpty {
            Section {
                EmptyPlansView()
            }
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(filteredPlans) { plan in
                    AvailablePlanRowView(
                        plan: plan,
                        isAlreadyAdded: existingPlanIds.contains(plan.id),
                        onSelect: { addPlan(plan) }
                    )
                }
            } header: {
                Text(L10n.tr("plan_available_section"))
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }

    // MARK: - Actions

    private func createDraftCycle() {
        guard draftCycle == nil else { return }
        let cycle = PlanCycle(profileId: profile.id, name: L10n.tr("cycle_new_title"))
        modelContext.insert(cycle)
        draftCycle = cycle
    }

    private func addPlan(_ plan: WorkoutPlan) {
        guard let cycle = draftCycle else { return }
        CycleService.addPlan(to: cycle, plan: plan, modelContext: modelContext)
    }

    private func removePlan(_ item: PlanCycleItem) {
        guard let cycle = draftCycle else { return }
        cycle.items.removeAll { $0.id == item.id }
        modelContext.delete(item)
    }

    private func completeWizard() {
        guard let cycle = draftCycle else {
            dismiss()
            return
        }

        do {
            try modelContext.save()
            onComplete(cycle)
        } catch {
            print("Error saving cycle: \(error)")
        }
        dismiss()
    }

    private func cancelWizard() {
        if let cycle = draftCycle {
            for item in cycle.items {
                modelContext.delete(item)
            }
            modelContext.delete(cycle)
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - Added Plan Row View

private struct AddedPlanRowView: View {
    let item: PlanCycleItem
    let modelContext: ModelContext
    let onRemove: () -> Void

    @State private var plan: WorkoutPlan?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan?.name ?? L10n.tr("unknown_plan"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                if let plan = plan {
                    Text(L10n.tr("plan_summary_days_exercises", plan.dayCount, plan.totalExerciseCount))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadPlan()
        }
    }

    private func loadPlan() {
        if item.plan == nil {
            item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
        }
        plan = item.plan
    }
}

// MARK: - Available Plan Row View

private struct AvailablePlanRowView: View {
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

                    Text(L10n.tr("plan_summary_days_exercises", plan.dayCount, plan.totalExerciseCount))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isAlreadyAdded {
                    Text(L10n.tr("plan_already_added"))
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

// MARK: - Empty Plans View

private struct EmptyPlansView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textMuted)

            Text(L10n.tr("plan_empty_title"))
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Text(L10n.tr("plan_create_first"))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LocalProfile.self, PlanCycle.self, PlanCycleItem.self,
        WorkoutPlan.self, PlanDay.self,
        configurations: config
    )

    let profile = LocalProfile()
    container.mainContext.insert(profile)

    return CycleCreationWizardView(
        profile: profile,
        onComplete: { _ in }
    )
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
