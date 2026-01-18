//
//  RoutinesView.swift
//  Routyra
//
//  Main view for managing workout plans and execution mode.
//  Handles single plan and cycle mode selection.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var profile: LocalProfile?
    @State private var plans: [WorkoutPlan] = []
    @State private var cycles: [PlanCycle] = []
    @State private var activeCycle: PlanCycle?
    @State private var navigationPath = NavigationPath()
    @State private var newlyCreatedPlanId: UUID?

    // Ad manager
    @StateObject private var adManager = NativeAdManager()

    // Plan Guide
    @AppStorage("hasSeenPlanGuide") private var hasSeenPlanGuide = false
    @State private var showPlanGuide = false

    // Spotlight for Add Plan button
    @AppStorage("hasShownPlanAddSpotlight") private var hasShownPlanAddSpotlight = false
    @State private var showSpotlight = false
    @State private var planAddButtonFrame: CGRect = .zero

    // Alerts & Sheets
    @State private var planToDelete: WorkoutPlan?
    @State private var cycleToDelete: PlanCycle?
    @State private var showNewPlanAlert: Bool = false
    @State private var newPlanName: String = ""
    @State private var showNewCycleAlert: Bool = false
    @State private var newCycleName: String = ""
    @State private var cycleDraftName: String = ""
    @State private var showCycleWizard: Bool = false
    @State private var showActivePlanPicker: Bool = false
    @State private var showCyclePicker: Bool = false
    @State private var showDeleteActiveWarning: Bool = false
    @State private var showDeleteActiveCycleWarning: Bool = false
    @State private var pendingPlan: WorkoutPlan?
    @State private var pendingCycle: PlanCycle?

    private var deletePlanPresented: Binding<Bool> {
        Binding(
            get: { planToDelete != nil && !showDeleteActiveWarning },
            set: { if !$0 { planToDelete = nil } }
        )
    }

    private var deleteCyclePresented: Binding<Bool> {
        Binding(
            get: { cycleToDelete != nil && !showDeleteActiveCycleWarning },
            set: { if !$0 { cycleToDelete = nil } }
        )
    }

    var body: some View {
        bodyContent
    }

    @ViewBuilder
    private var bodyContent: some View {
        NavigationStack(path: $navigationPath) {
            navigationStackContent
        }
        .overlay {
            if showPlanGuide {
                PlanGuideOverlayView(
                    isPresented: $showPlanGuide,
                    hasSeenGuide: $hasSeenPlanGuide
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .overlay {
            // フレームが有効な場合のみスポットライト表示
            if showSpotlight && planAddButtonFrame.width > 0 {
                SpotlightOverlayView(
                    targetFrame: planAddButtonFrame,
                    label: L10n.tr("spotlight_create_plan_hint"),
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSpotlight = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: showPlanGuide) { _, newValue in
            if newValue == false && !hasShownPlanAddSpotlight {
                // Delay to allow guide overlay to disappear and frame to be captured
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // フレームが有効な場合のみ表示・フラグ更新
                    if planAddButtonFrame.width > 0 {
                        showSpotlight = true
                        hasShownPlanAddSpotlight = true
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: showPlanGuide)
        .animation(.easeOut(duration: 0.2), value: showSpotlight)
    }

    private var navigationStackContent: some View {
        let base = AnyView(
            listContent
                .background(AppColors.background)
                .navigationBarTitleDisplayMode(.inline)
        )

        let destinations = AnyView(
            base
                .navigationDestination(for: WorkoutPlan.self) { plan in
                    PlanEditorView(plan: plan, allowEmptyPlan: plan.id == newlyCreatedPlanId)
                        .onDisappear {
                            loadData()
                            newlyCreatedPlanId = nil
                        }
                }
                .navigationDestination(for: PlanCycle.self) { cycle in
                    CycleEditorView(cycle: cycle)
                        .onDisappear {
                            loadCycles()
                            loadActiveCycle()
                        }
                }
        )

        let lifecycle = AnyView(
            destinations
                .onAppear {
                    loadData()
                    // Show guide on first access (hasSeenGuide is set when overlay closes)
                    if !hasSeenPlanGuide {
                        showPlanGuide = true
                    }
                    // Load ads
                    if adManager.nativeAds.isEmpty {
                        adManager.loadNativeAds(count: 3)
                    }
                }
        )

        let alerts = AnyView(
            lifecycle
            .alert("delete_plan", isPresented: deletePlanPresented) {
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
            .alert("delete_cycle", isPresented: deleteCyclePresented) {
                    Button("delete", role: .destructive) {
                        if let cycle = cycleToDelete {
                            deleteCycle(cycle)
                        }
                    }
                    Button("cancel", role: .cancel) {
                        cycleToDelete = nil
                    }
                } message: {
                    Text(L10n.tr("delete_cycle_confirm", cycleToDelete?.name ?? ""))
                }
                .alert("delete_active_cycle", isPresented: $showDeleteActiveCycleWarning) {
                    Button("delete", role: .destructive) {
                        if let cycle = cycleToDelete {
                            deleteCycle(cycle)
                        }
                        showDeleteActiveCycleWarning = false
                    }
                    Button("cancel", role: .cancel) {
                        cycleToDelete = nil
                        showDeleteActiveCycleWarning = false
                    }
                } message: {
                    Text("delete_active_cycle_warning")
                }
                .alert("add_plan", isPresented: $showNewPlanAlert) {
                    TextField(L10n.tr("new_plan"), text: $newPlanName)
                    Button("cancel", role: .cancel) {}
                    Button("create") {
                        createPlanFromAlert()
                    }
                }
                .alert("cycle_create", isPresented: $showNewCycleAlert) {
                    TextField(L10n.tr("cycle_new_title"), text: $newCycleName)
                    Button("cancel", role: .cancel) {}
                    Button("create") {
                        createCycleFromAlert()
                    }
                }
        )

        let sheets = AnyView(
            alerts
                .fullScreenCover(isPresented: $showCycleWizard) {
                    if let profile = profile {
                        CycleCreationWizardView(
                            profile: profile,
                            cycleName: cycleDraftName
                        ) { cycle in
                            loadCycles()
                            loadActiveCycle()
                            // Navigate to CycleEditorView after wizard completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigationPath.append(cycle)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showActivePlanPicker) {
                    ActivePlanPickerSheet(
                        plans: plans,
                        activePlanId: profile?.activePlanId
                    ) { selectedPlan in
                        if let plan = selectedPlan {
                            // Deactivate all cycles when selecting a single plan
                            if let profile = profile {
                                CycleService.deactivateAllCycles(
                                    profileId: profile.id,
                                    modelContext: modelContext
                                )
                                loadActiveCycle()
                            }
                            // Delay to allow picker sheet to dismiss first
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                pendingPlan = plan
                            }
                        } else {
                            clearActivePlan()
                        }
                    }
                }
                .sheet(isPresented: $showCyclePicker) {
                    if let profile = profile {
                        ActiveCyclePickerSheet(
                            cycles: cycles,
                            activeCycleId: activeCycle?.id
                        ) { selectedCycle in
                            if let cycle = selectedCycle {
                                // Delay to allow picker sheet to dismiss first
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    pendingCycle = cycle
                                }
                            } else {
                                // None selected - deactivate all cycles
                                CycleService.deactivateAllCycles(
                                    profileId: profile.id,
                                    modelContext: modelContext
                                )
                                profile.scheduledCycleStartDate = nil
                                profile.scheduledCyclePlanIndex = nil
                                profile.scheduledCycleDayIndex = nil
                                profile.scheduledCycleId = nil
                                loadActiveCycle()
                                try? modelContext.save()
                            }
                        }
                    }
                }
                .sheet(item: $pendingPlan) { plan in
                    if let profile = profile {
                        PlanStartPickerSheet(
                            plan: plan,
                            todayHasWorkoutData: checkTodayHasWorkoutData()
                        ) { timing, startDayIndex, startDate in
                            applyPlan(plan, timing: timing, startDayIndex: startDayIndex, startDate: startDate)
                            pendingPlan = nil
                        }
                    }
                }
                .sheet(item: $pendingCycle) { cycle in
                    CycleStartPickerSheet(
                        cycle: cycle,
                        todayHasWorkoutData: checkTodayHasWorkoutData()
                    ) { timing, planIndex, dayIndex, startDate in
                        applyCycle(cycle, timing: timing, planIndex: planIndex, dayIndex: dayIndex, startDate: startDate)
                        pendingCycle = nil
                    }
                }
        )

        return sheets
    }

    private var listContent: some View {
        List {
            headerRow
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            executionModeSection
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            currentOperationSection
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Text(L10n.tr("library"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            librarySection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var headerRow: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Text("workout_plans")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Button {
                    showPlanGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
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

            // Hint text
            Text(executionModeHint)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private var executionModeHint: String {
        if profile?.executionMode == .cycle {
            return L10n.tr("execution_mode_cycle_hint")
        }
        return L10n.tr("execution_mode_single_hint")
    }

    // MARK: - Current Operation Section (Unified)

    private var currentOperationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text(L10n.tr("current_operation"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // Operation card
            Button {
                if profile?.executionMode == .cycle {
                    showCyclePicker = true
                } else {
                    showActivePlanPicker = true
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Label (mode-specific)
                        Text(profile?.executionMode == .cycle
                             ? L10n.tr("active_cycle")
                             : L10n.tr("active_plan"))
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)

                        // Main value
                        Text(currentOperationName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)

                        // Summary (only when set)
                        if let summary = currentOperationSummary {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        // Empty hint (only when not set)
                        if !hasActiveOperation {
                            Text(L10n.tr("current_operation_empty_hint"))
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }
                    }

                    Spacer()

                    // Right side: checkmark + chevron (when set) or just chevron (when not set)
                    if hasActiveOperation {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accentBlue)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var hasActiveOperation: Bool {
        if profile?.executionMode == .cycle {
            return activeCycle != nil
        } else {
            return profile?.activePlanId != nil && plans.contains { $0.id == profile?.activePlanId }
        }
    }

    private var currentOperationName: String {
        if profile?.executionMode == .cycle {
            return activeCycle?.name ?? L10n.tr("not_set")
        } else {
            guard let activePlanId = profile?.activePlanId,
                  let plan = plans.first(where: { $0.id == activePlanId }) else {
                return L10n.tr("not_set")
            }
            return plan.name
        }
    }

    private var currentOperationSummary: String? {
        if profile?.executionMode == .cycle {
            guard let profile = profile,
                  let cycle = activeCycle else { return nil }
            if let scheduledDate = profile.scheduledCycleStartDate,
               let scheduledCycleId = profile.scheduledCycleId,
               scheduledCycleId == cycle.id,
               scheduledDate > DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour) {
                return L10n.tr("plan_start_scheduled_summary", DateUtilities.formatShort(scheduledDate))
            }
            return L10n.tr("cycle_plan_count", cycle.sortedItems.count)
        } else {
            guard let profile = profile,
                  let activePlanId = profile.activePlanId,
                  let plan = plans.first(where: { $0.id == activePlanId }) else {
                return nil
            }
            if let scheduledDate = profile.scheduledPlanStartDate,
               let scheduledPlanId = profile.scheduledPlanId,
               scheduledPlanId == activePlanId,
               scheduledDate > DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour) {
                return L10n.tr("plan_start_scheduled_summary", DateUtilities.formatShort(scheduledDate))
            }
            return L10n.tr("plan_summary_days_exercises", plan.dayCount, plan.totalExerciseCount)
        }
    }

    // MARK: - Library Section (Unified)

    @ViewBuilder
    private var librarySection: some View {
        // CTA card (mode-specific action, same style)
        if profile?.executionMode == .cycle {
            Button {
                newCycleName = ""
                showNewCycleAlert = true
            } label: {
                ActionCardButton(
                    title: L10n.tr("cycle_create"),
                    subtitle: L10n.tr("cycle_empty_description"),
                    icon: "plus",
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Button {
                newPlanName = ""
                showNewPlanAlert = true
            } label: {
                ActionCardButton(
                    title: L10n.tr("add_plan"),
                    subtitle: L10n.tr("add_plan_subtitle"),
                    icon: "plus",
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            planAddButtonFrame = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                            planAddButtonFrame = newFrame
                        }
                }
            )
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }

        // List (mode-specific content)
        if profile?.executionMode == .cycle {
            cycleListContent
        } else {
            planListContent
        }
    }

    @ViewBuilder
    private var planListContent: some View {
        if plans.isEmpty {
            emptyPlansMessage
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            // Show ad below empty message
            if shouldShowPlanAd {
                NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
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
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Show ad after every 4 plans (only if more than 3 plans)
                if let adIndex = shouldShowPlanAdAfterIndex(index),
                   adIndex < adManager.nativeAds.count {
                    NativeAdCardView(nativeAd: adManager.nativeAds[adIndex])
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // Show ad at bottom for 3 or fewer plans
            if plans.count <= 3, shouldShowPlanAd {
                NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private var shouldShowPlanAd: Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    private func shouldShowPlanAdAfterIndex(_ index: Int) -> Int? {
        guard !(profile?.isPremiumUser ?? false) else { return nil }
        guard plans.count > 3 else { return nil }
        guard (index + 1) % 4 == 0 else { return nil }
        let adIndex = (index + 1) / 4 - 1
        return adIndex
    }

    @ViewBuilder
    private var cycleListContent: some View {
        if cycles.isEmpty {
            emptyCyclesMessage
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            // Show ad below empty message
            if shouldShowCycleAd {
                NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(Array(cycles.enumerated()), id: \.element.id) { index, cycle in
                CycleCardView(
                    cycle: cycle,
                    isActive: isActiveCycle(cycle),
                    onTap: {
                        navigationPath.append(cycle)
                    },
                    onDelete: {
                        requestDeleteCycle(cycle)
                    }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Show ad after every 4 cycles (only if more than 3 cycles)
                if let adIndex = shouldShowCycleAdAfterIndex(index),
                   adIndex < adManager.nativeAds.count {
                    NativeAdCardView(nativeAd: adManager.nativeAds[adIndex])
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // Show ad at bottom for 3 or fewer cycles
            if cycles.count <= 3, shouldShowCycleAd {
                NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private var shouldShowCycleAd: Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    private func shouldShowCycleAdAfterIndex(_ index: Int) -> Int? {
        guard !(profile?.isPremiumUser ?? false) else { return nil }
        guard cycles.count > 3 else { return nil }
        guard (index + 1) % 4 == 0 else { return nil }
        let adIndex = (index + 1) / 4 - 1
        return adIndex
    }

    // MARK: - Helper Functions

    private func isActiveCycle(_ cycle: PlanCycle) -> Bool {
        guard profile?.executionMode == .cycle else { return false }
        return cycle.isActive
    }

    private func isActivePlan(_ plan: WorkoutPlan) -> Bool {
        guard profile?.executionMode == .single else { return false }
        return profile?.activePlanId == plan.id
    }

    // MARK: - Empty State Messages

    private var emptyCyclesMessage: some View {
        VStack(spacing: 8) {
            Text("no_cycles")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Text("create_cycle_hint")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

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
        loadCycles()
    }

    private func loadActiveCycle() {
        guard let profile = profile else {
            activeCycle = nil
            return
        }
        activeCycle = CycleService.getActiveCycle(profileId: profile.id, modelContext: modelContext)
    }

    private func loadCycles() {
        guard let profile = profile else {
            cycles = []
            return
        }
        cycles = CycleService.getCycles(profileId: profile.id, modelContext: modelContext)
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
            profile?.scheduledPlanStartDate = nil
            profile?.scheduledPlanStartDayIndex = nil
            profile?.scheduledPlanId = nil
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

    private func createPlanFromAlert() {
        guard let profile = profile else { return }

        let trimmedName = newPlanName.trimmingCharacters(in: .whitespacesAndNewlines)
        let planName = trimmedName.isEmpty ? L10n.tr("new_plan") : trimmedName

        let plan = WorkoutPlan(profileId: profile.id, name: planName)
        modelContext.insert(plan)
        try? modelContext.save()
        loadData()
        newlyCreatedPlanId = plan.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigationPath.append(plan)
        }
    }

    private func createCycleFromAlert() {
        let trimmedName = newCycleName.trimmingCharacters(in: .whitespacesAndNewlines)
        cycleDraftName = trimmedName.isEmpty ? L10n.tr("cycle_new_title") : trimmedName
        showCycleWizard = true
    }

    private func setActivePlan(_ plan: WorkoutPlan) {
        profile?.activePlanId = plan.id
        profile?.scheduledPlanStartDate = nil
        profile?.scheduledPlanStartDayIndex = nil
        profile?.scheduledPlanId = nil
        try? modelContext.save()
    }

    private func clearActivePlan() {
        profile?.activePlanId = nil
        profile?.scheduledPlanStartDate = nil
        profile?.scheduledPlanStartDayIndex = nil
        profile?.scheduledPlanId = nil
        try? modelContext.save()
    }

    private func activateCycle(_ cycle: PlanCycle) {
        guard let profile = profile else { return }

        // Clear single plan when activating a cycle
        profile.activePlanId = nil
        profile.scheduledPlanStartDate = nil
        profile.scheduledPlanStartDayIndex = nil
        profile.scheduledPlanId = nil
        profile.scheduledCycleStartDate = nil
        profile.scheduledCyclePlanIndex = nil
        profile.scheduledCycleDayIndex = nil
        profile.scheduledCycleId = nil

        // Switch execution mode to cycle
        profile.executionMode = .cycle

        // Activate the selected cycle
        CycleService.setActiveCycle(cycle, profileId: profile.id, modelContext: modelContext)

        try? modelContext.save()
        loadActiveCycle()
        loadCycles()
    }

    private func applyCycle(
        _ cycle: PlanCycle,
        timing: PlanStartTiming,
        planIndex: Int,
        dayIndex: Int,
        startDate: Date?
    ) {
        guard let profile = profile else { return }

        // Clear single plan when activating a cycle
        profile.activePlanId = nil
        profile.scheduledPlanStartDate = nil
        profile.scheduledPlanStartDayIndex = nil
        profile.scheduledPlanId = nil
        profile.scheduledCycleStartDate = nil
        profile.scheduledCyclePlanIndex = nil
        profile.scheduledCycleDayIndex = nil
        profile.scheduledCycleId = nil

        // Switch execution mode to cycle
        profile.executionMode = .cycle

        // Activate the selected cycle
        CycleService.setActiveCycle(cycle, profileId: profile.id, modelContext: modelContext)

        let todayWorkoutDate = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        let normalizedStartDate = startDate.map { DateUtilities.startOfDay($0) }

        let applyCycleToToday = {
            if let (plan, planDay) = CycleService.getCurrentPlanDay(for: cycle, modelContext: modelContext) {
                let workoutDate = todayWorkoutDate
                let workoutDay = WorkoutService.getOrCreateWorkoutDay(
                    profileId: profile.id,
                    date: workoutDate,
                    mode: .routine,
                    routinePresetId: plan.id,
                    routineDayId: planDay.id,
                    modelContext: modelContext
                )
                // Clear existing entries
                for entry in workoutDay.entries {
                    modelContext.delete(entry)
                }
                workoutDay.entries.removeAll()

                // Set mode and routine info
                workoutDay.mode = .routine
                workoutDay.routinePresetId = plan.id
                workoutDay.routineDayId = planDay.id

                // Expand plan to workout
                PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay, modelContext: modelContext)
            }
        }

        switch timing {
        case .today, .nextWorkout:
            if let progress = cycle.progress {
                progress.currentItemIndex = planIndex
                progress.currentDayIndex = dayIndex
                progress.lastAdvancedAt = Date()
            }
            applyCycleToToday()
        case .scheduled:
            if let scheduledDate = normalizedStartDate, scheduledDate <= todayWorkoutDate {
                if let progress = cycle.progress {
                    progress.currentItemIndex = planIndex
                    progress.currentDayIndex = dayIndex
                    progress.lastAdvancedAt = Date()
                }
                applyCycleToToday()
            } else if let scheduledDate = normalizedStartDate {
                if let progress = cycle.progress {
                    progress.currentItemIndex = planIndex
                    progress.currentDayIndex = dayIndex
                    progress.lastAdvancedAt = nil
                }
                profile.scheduledCycleStartDate = scheduledDate
                profile.scheduledCyclePlanIndex = planIndex
                profile.scheduledCycleDayIndex = dayIndex
                profile.scheduledCycleId = cycle.id
            } else {
                if let progress = cycle.progress {
                    progress.currentItemIndex = planIndex
                    progress.currentDayIndex = dayIndex
                    progress.lastAdvancedAt = Date()
                }
                applyCycleToToday()
            }
        }

        try? modelContext.save()
        loadActiveCycle()
        loadCycles()
    }

    private func requestDeleteCycle(_ cycle: PlanCycle) {
        cycleToDelete = cycle

        // Check if this is the active cycle
        if cycle.isActive {
            showDeleteActiveCycleWarning = true
            return
        }
    }

    private func deleteCycle(_ cycle: PlanCycle) {
        if let profile = profile,
           profile.scheduledCycleId == cycle.id {
            profile.scheduledCycleStartDate = nil
            profile.scheduledCyclePlanIndex = nil
            profile.scheduledCycleDayIndex = nil
            profile.scheduledCycleId = nil
        }

        // Delete all cycle items first
        for item in cycle.sortedItems {
            modelContext.delete(item)
        }

        // Delete progress if exists
        if let progress = cycle.progress {
            modelContext.delete(progress)
        }

        modelContext.delete(cycle)
        try? modelContext.save()
        cycleToDelete = nil
        loadCycles()
        loadActiveCycle()
    }

    // MARK: - Plan Start Actions

    private func checkTodayHasWorkoutData() -> Bool {
        guard let profile = profile else { return false }
        let workoutDate = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        if let todayWorkout = WorkoutService.getWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            modelContext: modelContext
        ) {
            // Check if any set has actual logged data
            for entry in todayWorkout.entries {
                for workoutSet in entry.sortedSets {
                    if hasActualData(workoutSet) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func hasActualData(_ workoutSet: WorkoutSet) -> Bool {
        switch workoutSet.metricType {
        case .weightReps:
            return (workoutSet.weight ?? 0) > 0 || (workoutSet.reps ?? 0) > 0
        case .bodyweightReps:
            return (workoutSet.reps ?? 0) > 0
        case .timeDistance:
            return (workoutSet.durationSeconds ?? 0) > 0 || (workoutSet.distanceMeters ?? 0) > 0
        case .completion:
            return workoutSet.isCompleted
        }
    }

    private func applyPlan(
        _ plan: WorkoutPlan,
        timing: PlanStartTiming,
        startDayIndex: Int,
        startDate: Date?
    ) {
        guard let profile = profile else { return }

        // 1. Create/update PlanProgress and set start day
        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: modelContext
        )
        progress.currentDayIndex = startDayIndex

        // Reset any scheduled plan start
        profile.scheduledPlanStartDate = nil
        profile.scheduledPlanStartDayIndex = nil
        profile.scheduledPlanId = nil

        // 2. Set activePlanId
        profile.activePlanId = plan.id

        // 3. Apply now or schedule for a future date
        let todayWorkoutDate = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        let normalizedStartDate = startDate.map { DateUtilities.startOfDay($0) }

        switch timing {
        case .today, .nextWorkout:
            progress.lastOpenedDate = todayWorkoutDate
            _ = PlanService.applyPlanToday(
                profile: profile,
                plan: plan,
                dayIndex: startDayIndex,
                modelContext: modelContext
            )
        case .scheduled:
            if let scheduledDate = normalizedStartDate {
                if scheduledDate <= todayWorkoutDate {
                    progress.lastOpenedDate = todayWorkoutDate
                    _ = PlanService.applyPlanToday(
                        profile: profile,
                        plan: plan,
                        dayIndex: startDayIndex,
                        modelContext: modelContext
                    )
                } else {
                    progress.lastOpenedDate = nil
                    profile.scheduledPlanStartDate = scheduledDate
                    profile.scheduledPlanStartDayIndex = startDayIndex
                    profile.scheduledPlanId = plan.id
                }
            } else {
                progress.lastOpenedDate = todayWorkoutDate
                _ = PlanService.applyPlanToday(
                    profile: profile,
                    plan: plan,
                    dayIndex: startDayIndex,
                    modelContext: modelContext
                )
            }
        }

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
                        ActiveBadge()
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

// MARK: - Cycle Card View

private struct CycleCardView: View {
    let cycle: PlanCycle
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
                    Text(cycle.name.isEmpty ? L10n.tr("cycle_new_title") : cycle.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if isActive {
                        ActiveBadge()
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                // Summary
                Label(
                    L10n.tr("cycle_plan_count", cycle.sortedItems.count),
                    systemImage: "doc.on.doc"
                )
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
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
