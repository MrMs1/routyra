//
//  PlanStartPickerSheet.swift
//  Routyra
//
//  Sheet for selecting when to start a plan (today or next workout)
//  and which day to start from.
//

import SwiftUI
import SwiftData

// MARK: - PlanStartTiming

enum PlanStartTiming {
    case today
    case nextWorkout
    case scheduled
}

// MARK: - PlanStartPickerSheet

struct PlanStartPickerSheet: View {
    let plan: WorkoutPlan
    let todayHasWorkoutData: Bool
    let onConfirm: (PlanStartTiming, Int, Date?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTiming: PlanStartTiming = .today
    @State private var selectedDayIndex: Int = 1
    @State private var showDayPicker: Bool = false
    @State private var scheduledStartDate: Date = DateUtilities.today

    private var sortedDays: [PlanDay] {
        plan.sortedDays
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header: Title + Subtitle
                VStack(spacing: 8) {
                    Text(L10n.tr("plan_start_title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(L10n.tr("plan_start_subtitle", startSummaryText))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 24)

                Spacer()

                // Main content: Timing + Details + Confirm
                VStack(spacing: 16) {
                    StartTimingSection(
                        selectedTiming: $selectedTiming,
                        scheduledStartDate: $scheduledStartDate,
                        todayHasWorkoutData: todayHasWorkoutData
                    )

                    // Start Day selector (directly below buttons)
                    startDaySelector

                    Text(L10n.tr("plan_start_day_help"))
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    KeyValueSummaryCard(rows: [
                        .init(label: L10n.tr("plan_start_mode_label"), value: startModeValueText),
                        .init(label: L10n.tr("plan_start_day_label"), value: dayDisplayText),
                    ])
                    confirmButton
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDayPicker) {
                PlanStartDayPickerSheet(
                    days: sortedDays,
                    selectedDayIndex: $selectedDayIndex
                )
            }
        }
    }

    // MARK: - Start Day Selector

    private var startDaySelector: some View {
        Button {
            showDayPicker = true
        } label: {
            HStack {
                Text(L10n.tr("plan_start_day_label"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: 6) {
                    Text(dayDisplayText)
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

    // MARK: - Summary + Confirm

    private var confirmButton: some View {
        Button {
            let startDate = selectedTiming == .scheduled ? scheduledStartDate : nil
            onConfirm(selectedTiming, selectedDayIndex, startDate)
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

    private var startSummaryText: String {
        "\(startModeValueText) (\(dayDisplayText))"
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

    private var dayDisplayText: String {
        guard selectedDayIndex >= 1 && selectedDayIndex <= sortedDays.count else {
            return L10n.tr("day_label", 1)
        }
        let day = sortedDays[selectedDayIndex - 1]
        let base = L10n.tr("day_label", selectedDayIndex)
        if let name = day.name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty,
           name != base,
           name != "Day \(selectedDayIndex)" {
            return "\(base) (\(name))"
        }
        return base
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutPlan.self, PlanDay.self, configurations: config)

    let plan = WorkoutPlan(profileId: UUID(), name: "Push/Pull/Legs")
    for i in 1...3 {
        let day = plan.createDay()
        if i == 1 { day.name = "Push" }
        else if i == 2 { day.name = "Pull" }
        else { day.name = "Legs" }
    }
    container.mainContext.insert(plan)

    return PlanStartPickerSheet(
        plan: plan,
        todayHasWorkoutData: false
    ) { timing, dayIndex, startDate in
        print("Selected timing: \(timing), day: \(dayIndex), date: \(String(describing: startDate))")
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
