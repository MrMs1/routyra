//
//  PlanExerciseRowView.swift
//  Routyra
//
//  Displays an exercise within a plan day.
//  Collapsible: shows summary when collapsed, inline set editing when expanded.
//

import SwiftUI
import SwiftData

struct PlanExerciseRowView: View {
    @Bindable var planExercise: PlanExercise
    let exercise: Exercise?
    let bodyPart: BodyPart?
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            headerRow

            // Expanded content (set editing)
            if isExpanded {
                expandedContent
                    .transition(.opacity.animation(.easeOut(duration: 1)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("duplicate", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Expand/collapse button area
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    // Chevron (left side like PlanDayCardView)
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
                        Text(planExercise.setsSummary)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Set list (mini card rows)
            let sets = planExercise.sortedPlannedSets
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, plannedSet in
                PlannedSetCardRowView(
                    plannedSet: plannedSet,
                    setIndex: index + 1,
                    onDelete: {
                        planExercise.removePlannedSet(plannedSet)
                        planExercise.reindexPlannedSets()
                    }
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

            // Add set button (card-style)
            addSetButton
                .padding(.top, 8)
        }
        .padding(.top, 10)
    }

    // MARK: - Add Set Button

    private var addSetButton: some View {
        Button {
            // Copy weight/reps from last set if available
            let lastSet = planExercise.sortedPlannedSets.last
            planExercise.createPlannedSet(
                weight: lastSet?.targetWeight,
                reps: lastSet?.targetReps ?? 10
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accentBlue)

                Text("add_set")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentBlue)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let planExercise = PlanExercise(exerciseId: UUID(), orderIndex: 0, plannedSetCount: 3)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 60, reps: 8)

    return VStack(spacing: 8) {
        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: false,
            onToggleExpand: {},
            onDelete: {},
            onDuplicate: {}
        )

        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: true,
            onToggleExpand: {},
            onDelete: {},
            onDuplicate: {}
        )
    }
    .padding()
    .background(AppColors.cardBackground)
    .preferredColorScheme(.dark)
}
