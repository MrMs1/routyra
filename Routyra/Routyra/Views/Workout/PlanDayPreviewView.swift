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
        VStack(alignment: .leading, spacing: 8) {
            // Day badge
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textMuted)

                Text(L10n.tr("workout_future_plan_preview"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.cardBackground)
            .cornerRadius(8)

            // Day info
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

                Text("\(dayIndex)/\(totalDays)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Exercise List

    private var exerciseListView: some View {
        VStack(spacing: 8) {
            ForEach(planDay.sortedExercises) { planExercise in
                let exercise = exercises[planExercise.exerciseId]
                let bodyPart = exercise.flatMap { bodyParts[$0.bodyPartId ?? UUID()] }
                let isExpanded = expandedExerciseIds.contains(planExercise.id)

                PlanExerciseCardView(
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
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
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
