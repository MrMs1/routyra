//
//  RoutinesView.swift
//  Routyra
//
//  Main view for managing workout plans and execution mode.
//  Handles single plan and cycle mode selection.
//

import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var profile: LocalProfile?
    @State private var plans: [WorkoutPlan] = []
    @State private var activeCycle: PlanCycle?
    @State private var navigationPath = NavigationPath()

    // Alerts
    @State private var planToDelete: WorkoutPlan?
    @State private var showNewPlanAlert: Bool = false
    @State private var newPlanName: String = ""
    @State private var showActivePlanPicker: Bool = false
    @State private var showDeleteActiveWarning: Bool = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text("workout_plans")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Content
                    LazyVStack(spacing: 12) {
                        // Execution mode section
                        executionModeSection

                        // Mode-specific settings
                        if profile?.executionMode == .single {
                            activePlanSection
                        } else {
                            cycleSection
                        }

                        // Divider
                        dividerSection

                        // Add plan card
                        addPlanCard

                        // Plans list
                        plansSection
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(plan: plan)
                    .onDisappear {
                        loadData()
                    }
            }
            .onAppear {
                loadData()
            }
            .alert("delete_plan", isPresented: .init(
                get: { planToDelete != nil && !showDeleteActiveWarning },
                set: { if !$0 { planToDelete = nil } }
            )) {
                Button("delete", role: .destructive) {
                    if let plan = planToDelete {
                        deletePlan(plan)
                    }
                }
                Button("cancel", role: .cancel) {
                    planToDelete = nil
                }
            } message: {
                Text(L10n.tr("delete_plan_confirm", planToDelete?.name ?? ""))
            }
            .alert("delete_active_plan", isPresented: $showDeleteActiveWarning) {
                Button("delete", role: .destructive) {
                    if let plan = planToDelete {
                        deletePlan(plan)
                    }
                    showDeleteActiveWarning = false
                }
                Button("cancel", role: .cancel) {
                    planToDelete = nil
                    showDeleteActiveWarning = false
                }
            } message: {
                Text("delete_active_plan_warning")
            }
            .alert("new_plan", isPresented: $showNewPlanAlert) {
                TextField("plan_name", text: $newPlanName)
                Button("cancel", role: .cancel) {}
                Button("create") {
                    createPlan()
                }
                .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("enter_plan_name")
            }
            .confirmationDialog(
                "select_active_plan",
                isPresented: $showActivePlanPicker,
                titleVisibility: .visible
            ) {
                ForEach(plans, id: \.id) { plan in
                    Button(plan.name) {
                        setActivePlan(plan)
                    }
                }
                Button("none") {
                    clearActivePlan()
                }
                Button("cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Execution Mode Section

    private var executionModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("execution_mode")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            Picker("", selection: Binding(
                get: { profile?.executionMode ?? .single },
                set: { newMode in
                    profile?.executionMode = newMode
                    try? modelContext.save()
                }
            )) {
                Text("single_plan").tag(ExecutionMode.single)
                Text("cycle").tag(ExecutionMode.cycle)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Active Plan Section (Single Mode)

    private var activePlanSection: some View {
        Button {
            showActivePlanPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("active_plan")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(activePlanName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var activePlanName: String {
        guard let activePlanId = profile?.activePlanId,
              let plan = plans.first(where: { $0.id == activePlanId }) else {
            return L10n.tr("not_set")
        }
        return plan.name
    }

    // MARK: - Cycle Section (Cycle Mode)

    private var cycleSection: some View {
        VStack(spacing: 0) {
            // Cycle toggle row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("cycle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    if let cycle = activeCycle {
                        Text(cycleSummary(for: cycle))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("no_active_cycle")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { activeCycle != nil },
                    set: { isOn in
                        if !isOn, let cycle = activeCycle {
                            CycleService.deactivateCycle(cycle)
                            try? modelContext.save()
                            loadActiveCycle()
                        }
                    }
                ))
                .labelsHidden()
            }
            .padding()

            // Edit button (navigate to cycle list)
            NavigationLink(destination: CycleListView()) {
                HStack {
                    Text("edit_cycles")
                        .font(.subheadline)
                        .foregroundColor(AppColors.accentBlue)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding()
                .background(AppColors.cardBackground.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private func cycleSummary(for cycle: PlanCycle) -> String {
        let planNames = cycle.sortedItems.compactMap { $0.plan?.name }
        if planNames.isEmpty {
            return L10n.tr("no_plans")
        }
        return planNames.joined(separator: " → ")
    }

    // MARK: - Divider Section

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(AppColors.textMuted.opacity(0.3))
                .frame(height: 1)

            Text("plans")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)

            Rectangle()
                .fill(AppColors.textMuted.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Add Plan Card

    private var addPlanCard: some View {
        Button {
            newPlanName = ""
            showNewPlanAlert = true
        } label: {
            ActionCardButton(
                title: L10n.tr("add_plan"),
                subtitle: L10n.tr("add_plan_subtitle"),
                icon: "plus",
                showChevron: false
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plans Section

    private var plansSection: some View {
        Group {
            if plans.isEmpty {
                emptyPlansMessage
            } else {
                ForEach(plans, id: \.id) { plan in
                    PlanCardView(
                        plan: plan,
                        isActive: isActivePlan(plan),
                        onTap: {
                            navigationPath.append(plan)
                        },
                        onDelete: {
                            requestDeletePlan(plan)
                        }
                    )
                }
            }
        }
    }

    private func isActivePlan(_ plan: WorkoutPlan) -> Bool {
        guard profile?.executionMode == .single else { return false }
        return profile?.activePlanId == plan.id
    }

    // MARK: - Empty Plans Message

    private var emptyPlansMessage: some View {
        VStack(spacing: 8) {
            Text("no_plans")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Text("create_plan_hint")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Actions

    private func loadData() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        guard let profile = profile else { return }

        plans = PlanService.getPlans(
            profileId: profile.id,
            modelContext: modelContext
        )

        loadActiveCycle()
    }

    private func loadActiveCycle() {
        guard let profile = profile else {
            activeCycle = nil
            return
        }
        activeCycle = CycleService.getActiveCycle(profileId: profile.id, modelContext: modelContext)
    }

    private func createPlan() {
        guard let profile = profile,
              !newPlanName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let trimmedName = newPlanName.trimmingCharacters(in: .whitespaces)
        let plan = WorkoutPlan(profileId: profile.id, name: trimmedName)

        // Create initial Day 1
        _ = plan.createDay()

        modelContext.insert(plan)
        try? modelContext.save()
        loadData()

        // Navigate to the created plan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigationPath.append(plan)
        }
    }

    private func requestDeletePlan(_ plan: WorkoutPlan) {
        planToDelete = plan

        // Check if this is the active plan in single mode
        if profile?.executionMode == .single && profile?.activePlanId == plan.id {
            showDeleteActiveWarning = true
            return
        }

        // Check if this plan is in a cycle
        // (Deletion will proceed, but we'll remove from cycles in deletePlan)
    }

    private func deletePlan(_ plan: WorkoutPlan) {
        // If this was the active plan in single mode, clear it
        if profile?.activePlanId == plan.id {
            profile?.activePlanId = nil
        }

        // Remove from any cycles
        removePlanFromCycles(plan)

        modelContext.delete(plan)
        try? modelContext.save()
        planToDelete = nil
        loadData()
    }

    private func removePlanFromCycles(_ plan: WorkoutPlan) {
        // Find all cycle items referencing this plan
        let planId = plan.id
        let descriptor = FetchDescriptor<PlanCycleItem>()

        if let items = try? modelContext.fetch(descriptor) {
            let matchingItems = items.filter { $0.plan?.id == planId }
            for item in matchingItems {
                if let cycle = item.cycle {
                    cycle.removeItem(item)
                    cycle.reindexItems()
                }
                modelContext.delete(item)
            }
        }
    }

    private func setActivePlan(_ plan: WorkoutPlan) {
        profile?.activePlanId = plan.id
        try? modelContext.save()
    }

    private func clearActivePlan() {
        profile?.activePlanId = nil
        try? modelContext.save()
    }
}

// MARK: - Plan Card View

private struct PlanCardView: View {
    let plan: WorkoutPlan
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(plan.name.isEmpty ? L10n.tr("new_plan") : plan.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if isActive {
                        Text("active")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                // Summary
                HStack(spacing: 16) {
                    Label(
                        "\(plan.dayCount)\(L10n.tr("days_unit"))",
                        systemImage: "calendar"
                    )
                    Label(
                        "\(plan.totalExerciseCount)\(L10n.tr("exercises_unit"))",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

                // Note
                if let note = plan.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    RoutinesView()
        .modelContainer(for: [
            LocalProfile.self,
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlannedSet.self,
            Exercise.self,
            BodyPart.self,
            BodyPartTranslation.self,
            ExerciseTranslation.self,
            PlanCycle.self,
            PlanCycleItem.self,
            PlanCycleProgress.self
        ], inMemory: true)
        .preferredColorScheme(.dark)
}
