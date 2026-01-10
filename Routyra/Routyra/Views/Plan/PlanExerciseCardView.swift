//
//  PlanExerciseCardView.swift
//  Routyra
//
//  Read-only exercise card for Plan viewing.
//  Shows exercise summary when collapsed, full set list when expanded.
//  Design unified with PlanExerciseRowView (editable version).
//

import SwiftUI

struct PlanExerciseCardView: View {
    let planExercise: PlanExercise
    let exercise: Exercise?
    let bodyPart: BodyPart?
    let isExpanded: Bool
    let onToggle: () -> Void
    var onEditSets: (() -> Void)? = nil
    var weightUnit: WeightUnit = .kg

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            headerRow

            // Expanded content (set list)
            if isExpanded {
                expandedContent
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 0)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                // Chevron (left side, matching PlanExerciseRowView)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
                    .frame(width: 16)

                // Exercise info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        // Body part color dot
                        if let bodyPart = bodyPart {
                            Circle()
                                .fill(bodyPart.color)
                                .frame(width: 8, height: 8)
                        }

                        Text(exercise?.localizedName ?? L10n.tr("unknown_exercise"))
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        // Body part chip
                        if let bodyPart = bodyPart {
                            Text(bodyPart.localizedName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.mutedBlue.opacity(0.2))
                                .foregroundColor(AppColors.textSecondary)
                                .cornerRadius(4)
                        }
                    }

                    // Summary
                    Text(planExercise.setsSummary(weightUnit: weightUnit))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Set list (mini card rows - tappable for editing)
            let sets = planExercise.sortedPlannedSets
            if sets.isEmpty {
                Text("no_sets_configured")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.vertical, 4)
            } else {
                Button {
                    onEditSets?()
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, plannedSet in
                            PlannedSetDisplayRow(
                                plannedSet: plannedSet,
                                setIndex: index + 1,
                                weightUnit: weightUnit
                            )

                            // Thin separator line (not after last row)
                            if index < sets.count - 1 {
                                Color.white.opacity(0.08)
                                    .frame(height: 1)
                                    .padding(.leading, 56)
                                    .padding(.trailing, 16)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
}

#Preview {
    let planExercise = PlanExercise(exerciseId: UUID(), orderIndex: 0, plannedSetCount: 3)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 65, reps: 8)

    return VStack(spacing: 12) {
        PlanExerciseCardView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: false,
            onToggle: {}
        )

        PlanExerciseCardView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: true,
            onToggle: {}
        )
    }
    .padding()
    .background(AppColors.cardBackground)
    .preferredColorScheme(.dark)
}
