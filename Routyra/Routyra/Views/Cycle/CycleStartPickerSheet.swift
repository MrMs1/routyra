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
    @State private var selectedTiming: PlanStartTiming = .today
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
                    StartTimingSection(
                        selectedTiming: $selectedTiming,
                        scheduledStartDate: $scheduledStartDate,
                        todayHasWorkoutData: todayHasWorkoutData
                    )

                    // Start Position selector
                    startPositionSelector

                    KeyValueSummaryCard(rows: [
                        .init(label: L10n.tr("plan_start_mode_label"), value: startModeValueText),
                        .init(label: L10n.tr("cycle_start_position_label"), value: positionDisplayText),
                    ])
                    confirmButton
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

    // MARK: - Confirm

    private var confirmButton: some View {
        Button {
            let startDate = selectedTiming == .scheduled ? scheduledStartDate : nil
            onConfirm(selectedTiming, selectedPlanIndex, selectedDayIndex, startDate)
            dismiss()
        } label: {
            Text(L10n.tr("plan_start_confirm"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.accentBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    private var startModeValueText: String {
        switch selectedTiming {
        case .today:
            return L10n.tr("today")
        case .nextWorkout:
            return L10n.tr("plan_start_next_workout")
        case .scheduled:
            return DateFormatter.localizedString(from: scheduledStartDate, dateStyle: .short, timeStyle: .none)
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
        let baseDay = L10n.tr("day_label", dayNumber)

        if selectedDayIndex < sortedDays.count,
           let rawName = sortedDays[selectedDayIndex].name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawName.isEmpty,
           rawName != baseDay,
           rawName != "Day \(dayNumber)" {
            return "\(planName) - \(baseDay) (\(rawName))"
        }

        return "\(planName) - \(baseDay)"
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
