//
//  CycleStartPickerSheet.swift
//  Routyra
//
//  Sheet for selecting when to start a cycle (today or scheduled date)
//  and which plan/day to start from.
//

import SwiftUI
import SwiftData

// MARK: - CycleStartPickerSheet

struct CycleStartPickerSheet: View {
    let cycle: PlanCycle
    let todayHasWorkoutData: Bool
    let onConfirm: (PlanStartTiming, Int, Int, Date?) -> Void  // (timing, planIndex, dayIndex, startDate)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPlanIndex: Int = 0  // 0-indexed
    @State private var selectedDayIndex: Int = 0   // 0-indexed
    @State private var showPositionPicker: Bool = false
    @State private var scheduledStartDate: Date = DateUtilities.today

    private var sortedItems: [PlanCycleItem] {
        cycle.sortedItems
    }

    private var currentPlan: WorkoutPlan? {
        guard selectedPlanIndex < sortedItems.count else { return nil }
        let item = sortedItems[selectedPlanIndex]
        if item.plan == nil {
            item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
        }
        return item.plan
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header: Title + Subtitle
                VStack(spacing: 8) {
                    Text(L10n.tr("cycle_start_title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(L10n.tr("cycle_start_subtitle", positionDisplayText))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 24)

                Spacer()

                // Main content: Buttons + Position selector
                VStack(spacing: 16) {
                    // Start timing buttons
                    VStack(spacing: 12) {
                        primaryButton(timing: .today, title: L10n.tr("plan_start_today"))
                        if todayHasWorkoutData {
                            Text(L10n.tr("plan_start_warning_replace_today"))
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 10) {
                            DatePicker(
                                L10n.tr("plan_start_date_label"),
                                selection: $scheduledStartDate,
                                in: DateUtilities.today...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)

                            secondaryButton(title: L10n.tr("plan_start_scheduled"))
                        }
                    }

                    // Start Position selector
                    startPositionSelector
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle(cycle.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPositionPicker) {
                CycleStartPositionPickerSheet(
                    cycle: cycle,
                    selectedPlanIndex: $selectedPlanIndex,
                    selectedDayIndex: $selectedDayIndex
                )
            }
        }
    }

    // MARK: - Primary Button

    private func primaryButton(timing: PlanStartTiming, title: String) -> some View {
        Button {
            onConfirm(timing, selectedPlanIndex, selectedDayIndex, nil)
            dismiss()
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.accentBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    // MARK: - Secondary Button

    private func secondaryButton(title: String) -> some View {
        Button {
            onConfirm(.scheduled, selectedPlanIndex, selectedDayIndex, scheduledStartDate)
            dismiss()
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.cardBackground)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(12)
        }
    }

    // MARK: - Start Position Selector

    private var startPositionSelector: some View {
        Button {
            showPositionPicker = true
        } label: {
            HStack {
                Text(L10n.tr("cycle_start_position_label"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: 6) {
                    Text(positionDisplayText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(AppColors.cardBackground)
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var positionDisplayText: String {
        guard let plan = currentPlan else {
            return L10n.tr("cycle_start_day_label", 1)
        }

        let planNumber = selectedPlanIndex + 1
        let dayNumber = selectedDayIndex + 1
        let planName = plan.name.isEmpty ? L10n.tr("new_plan") : plan.name

        let sortedDays = plan.sortedDays
        if selectedDayIndex < sortedDays.count,
           let dayName = sortedDays[selectedDayIndex].name,
           !dayName.isEmpty {
            return "\(planName) - Day \(dayNumber) (\(dayName))"
        }

        return "\(planName) - Day \(dayNumber)"
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

    return CycleStartPickerSheet(
        cycle: cycle,
        todayHasWorkoutData: false
    ) { timing, planIndex, dayIndex, startDate in
        print("Selected timing: \(timing), plan: \(planIndex), day: \(dayIndex), date: \(String(describing: startDate))")
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
