//
//  PlanDayPreviewView.swift
//  Routyra
//
//  Read-only preview of a plan day for future dates.
//  Shows the planned exercises without editing capabilities.
//

import SwiftUI

/// Read-only preview of a plan day for future dates
struct PlanDayPreviewView: View {
    let planDay: PlanDay
    let dayIndex: Int
    let totalDays: Int
    let exercises: [UUID: Exercise]
    let bodyParts: [UUID: BodyPart]
    var weightUnit: WeightUnit = .kg

    @State private var expandedExerciseIds: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with day info and preview badge
            headerView

            // Exercise list (read-only)
            exerciseListView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 4) {
            Text(L10n.tr("day_label", dayIndex))
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            if let dayName = planDay.name, !dayName.isEmpty {
                Text(":")
                    .font(.headline)
                    .foregroundColor(AppColors.textSecondary)
                Text(dayName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            // Preview badge (inline)
            HStack(spacing: 4) {
                Image(systemName: "eye")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textMuted)

                Text(L10n.tr("workout_future_plan_preview"))
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.cardBackground)
            .cornerRadius(6)

            Text("\(dayIndex)/\(totalDays)")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Display Items

    private var displayItems: [PlanDayDisplayItem] {
        PlanDayDisplayService.buildDisplayItems(from: planDay)
    }

    // MARK: - Exercise List

    private var exerciseListView: some View {
        VStack(spacing: 8) {
            ForEach(displayItems) { item in
                switch item {
                case .group(let group):
                    groupView(for: group)
                case .exercise(let planExercise):
                    exerciseCardView(for: planExercise)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Group View

    private func groupView(for group: PlanExerciseGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            groupHeaderView(group)

            ForEach(group.sortedExercises, id: \.id) { planExercise in
                exerciseCardView(for: planExercise)
                    .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(AppColors.background.opacity(0.5))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func groupHeaderView(_ group: PlanExerciseGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.caption)
                .foregroundColor(AppColors.accentBlue)
            Text(group.summary)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Exercise Card

    private func exerciseCardView(for planExercise: PlanExercise) -> some View {
        let exercise = exercises[planExercise.exerciseId]
        let bodyPart = exercise.flatMap { bodyParts[$0.bodyPartId ?? UUID()] }
        let isExpanded = expandedExerciseIds.contains(planExercise.id)

        return PlanExerciseCardView(
            planExercise: planExercise,
            exercise: exercise,
            bodyPart: bodyPart,
            isExpanded: isExpanded,
            onToggle: {
                toggleExercise(planExercise.id)
            },
            weightUnit: weightUnit
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func toggleExercise(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedExerciseIds.contains(id) {
                expandedExerciseIds.remove(id)
            } else {
                expandedExerciseIds.insert(id)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PlanDayPreviewView(
        planDay: PlanDay(dayIndex: 1, name: "Push Day"),
        dayIndex: 1,
        totalDays: 3,
        exercises: [:],
        bodyParts: [:]
    )
    .preferredColorScheme(.dark)
}
