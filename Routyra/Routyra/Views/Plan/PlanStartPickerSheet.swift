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

                    Text(L10n.tr("plan_start_subtitle", dayDisplayText))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 24)

                Spacer()

                // Main content: Buttons + Day selector
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

                    // Start Day selector (directly below buttons)
                    startDaySelector
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

    // MARK: - Primary Button

    private func primaryButton(timing: PlanStartTiming, title: String) -> some View {
        Button {
            onConfirm(timing, selectedDayIndex, nil)
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
            onConfirm(.scheduled, selectedDayIndex, scheduledStartDate)
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

    private var dayDisplayText: String {
        guard selectedDayIndex >= 1 && selectedDayIndex <= sortedDays.count else {
            return L10n.tr("day_label", 1)
        }
        let day = sortedDays[selectedDayIndex - 1]
        if let name = day.name, !name.isEmpty {
            return "\(L10n.tr("day_label", selectedDayIndex)) (\(name))"
        }
        return L10n.tr("day_label", selectedDayIndex)
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
