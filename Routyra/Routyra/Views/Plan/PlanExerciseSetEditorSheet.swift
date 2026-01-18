//
//  PlanExerciseSetEditorSheet.swift
//  Routyra
//
//  Shared sheet for editing sets of an existing plan exercise.
//

import SwiftUI
import SwiftData

enum PlanExerciseCandidateMode {
    case dayEditor
    case planEditor
}

struct PlanExerciseSetEditorSheet: View {
    let planExercise: PlanExercise
    let exercisesMap: [UUID: Exercise]
    let bodyPartsMap: [UUID: BodyPart]
    let candidateMode: PlanExerciseCandidateMode
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var profile: LocalProfile?

    private var exercise: Exercise? {
        exercisesMap[planExercise.exerciseId]
    }

    private var bodyPart: BodyPart? {
        guard let bodyPartId = exercise?.bodyPartId else { return nil }
        return bodyPartsMap[bodyPartId]
    }

    private var existingSets: [SetInputData] {
        planExercise.sortedPlannedSets.map { plannedSet in
            SetInputData(
                metricType: plannedSet.metricType,
                weight: plannedSet.targetWeight,
                reps: plannedSet.targetReps,
                durationSeconds: plannedSet.targetDurationSeconds,
                distanceMeters: plannedSet.targetDistanceMeters,
                restTimeSeconds: plannedSet.restTimeSeconds
            )
        }
    }

    private var isGrouped: Bool {
        planExercise.isGrouped
    }

    private var lockedSetCount: Int? {
        planExercise.group?.setCount
    }

    var body: some View {
        NavigationStack {
            if let exercise = exercise {
                if bodyPart?.code == "cardio" {
                    CardioTimeDistanceEntryView(
                        initialDurationSeconds: existingCardioDurationSeconds,
                        initialDistanceMeters: existingCardioDistanceMeters,
                        onConfirm: { durationSeconds, distanceMeters in
                            updateCardioSets(durationSeconds: durationSeconds, distanceMeters: distanceMeters)
                            onSave()
                            dismiss()
                        }
                    )
                } else {
                    let initialSets = buildInitialSets()
                    SetEditorView(
                        exercise: exercise,
                        bodyPart: bodyPart,
                        metricType: planExercise.metricType,
                        existingSets: initialSets,
                        config: .planEdit,
                        isSetCountEditingEnabled: !isGrouped,
                        isRestTimeEditingEnabled: !isGrouped,
                        candidateCollection: buildCandidateCollection(),
                        onConfirm: { newSets in
                            updateSets(newSets)
                            onSave()
                            dismiss()
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("cancel") {
                                dismiss()
                            }
                        }
                    }
                }
            } else {
                Text("exercise_not_found")
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .onAppear {
            if profile == nil {
                profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            }
        }
    }

    private func buildInitialSets() -> [SetInputData] {
        if !existingSets.isEmpty {
            return existingSets
        }

        let count = max(lockedSetCount ?? 1, 1)
        let base = SetInputData(metricType: planExercise.metricType, weight: 60, reps: 10)
        return Array(repeating: base, count: count)
    }

    private func buildCandidateCollection() -> CopyCandidateCollection {
        let exerciseId = planExercise.exerciseId
        guard let currentDay = planExercise.planDay,
              let currentPlan = currentDay.plan else {
            return .empty
        }

        var planCandidates: [PlanCopyCandidate] = []
        var workoutCandidates: [WorkoutCopyCandidate] = []

        switch candidateMode {
        case .dayEditor:
            // Priority order:
            // 1. Same Day's matching exercises (highest priority)
            // 2. Same Plan's other Days
            // 3. Other Plans

            // 1. Same Day candidates (excluding current exercise)
            let sameDayExercises = currentDay.sortedExercises
                .filter { $0.exerciseId == exerciseId && $0.id != planExercise.id }
            for planEx in sameDayExercises {
                let sets = planEx.sortedPlannedSets.map {
                    CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                }
                if !sets.isEmpty {
                    planCandidates.append(PlanCopyCandidate(
                        planId: currentPlan.id,
                        planName: currentPlan.name,
                        dayId: currentDay.id,
                        dayName: currentDay.fullTitle,
                        sets: sets,
                        updatedAt: currentPlan.updatedAt,
                        isCurrentPlan: true
                    ))
                }
            }

            // 2. Same Plan's other Days
            for day in currentPlan.sortedDays where day.id != currentDay.id {
                let matchingExercises = day.sortedExercises.filter { $0.exerciseId == exerciseId }
                for planEx in matchingExercises {
                    let sets = planEx.sortedPlannedSets.map {
                        CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                    }
                    if !sets.isEmpty {
                        planCandidates.append(PlanCopyCandidate(
                            planId: currentPlan.id,
                            planName: currentPlan.name,
                            dayId: day.id,
                            dayName: day.fullTitle,
                            sets: sets,
                            updatedAt: currentPlan.updatedAt,
                            isCurrentPlan: true
                        ))
                    }
                }
            }
        case .planEditor:
            // 1. Collect all plan candidates from current plan
            for day in currentPlan.sortedDays {
                let matchingExercises = day.sortedExercises
                    .filter { $0.exerciseId == exerciseId && $0.id != planExercise.id }

                for planEx in matchingExercises {
                    let sets = planEx.sortedPlannedSets.map {
                        CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                    }
                    if !sets.isEmpty {
                        planCandidates.append(PlanCopyCandidate(
                            planId: currentPlan.id,
                            planName: currentPlan.name,
                            dayId: day.id,
                            dayName: day.fullTitle,
                            sets: sets,
                            updatedAt: currentPlan.updatedAt,
                            isCurrentPlan: true
                        ))
                    }
                }
            }
        }

        // Other Plans (sorted by updatedAt desc)
        let descriptor = FetchDescriptor<WorkoutPlan>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        if let allPlans = try? modelContext.fetch(descriptor) {
            for plan in allPlans where plan.id != currentPlan.id {
                for day in plan.sortedDays {
                    let matchingExercises = day.sortedExercises.filter { $0.exerciseId == exerciseId }
                    for planEx in matchingExercises {
                        let sets = planEx.sortedPlannedSets.map {
                            CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                        }
                        if !sets.isEmpty {
                            planCandidates.append(PlanCopyCandidate(
                                planId: plan.id,
                                planName: plan.name,
                                dayId: day.id,
                                dayName: day.fullTitle,
                                sets: sets,
                                updatedAt: plan.updatedAt,
                                isCurrentPlan: false
                            ))
                        }
                    }
                }
            }
        }

        switch candidateMode {
        case .dayEditor:
            // Array is already in priority order, limit to 20 candidates
            planCandidates = Array(planCandidates.prefix(20))
        case .planEditor:
            // Sort: current plan first, then by updatedAt desc
            planCandidates.sort { lhs, rhs in
                if lhs.isCurrentPlan != rhs.isCurrentPlan {
                    return lhs.isCurrentPlan
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            // Limit to 20 candidates
            planCandidates = Array(planCandidates.prefix(20))
        }

        // Collect workout history candidates
        if let profile = profile {
            workoutCandidates = WorkoutService.getWorkoutHistorySets(
                profileId: profile.id,
                exerciseId: exerciseId,
                limit: 20,
                modelContext: modelContext
            )
        }

        return CopyCandidateCollection(
            planCandidates: planCandidates,
            workoutCandidates: workoutCandidates
        )
    }

    private var existingCardioDurationSeconds: Int {
        planExercise.sortedPlannedSets.first?.targetDurationSeconds ?? 0
    }

    private var existingCardioDistanceMeters: Double? {
        planExercise.sortedPlannedSets.first?.targetDistanceMeters
    }

    private func updateCardioSets(durationSeconds: Int, distanceMeters: Double?) {
        planExercise.metricType = .timeDistance
        let existingSets = planExercise.sortedPlannedSets

        if existingSets.isEmpty {
            planExercise.createPlannedSet(
                metricType: .timeDistance,
                durationSeconds: durationSeconds,
                distanceMeters: distanceMeters
            )
            planExercise.plannedSetCount = max(planExercise.plannedSetCount, 1)
            return
        }

        for set in existingSets {
            set.metricType = .timeDistance
            set.targetWeight = nil
            set.targetReps = nil
            set.restTimeSeconds = nil
            set.targetDurationSeconds = durationSeconds
            set.targetDistanceMeters = distanceMeters
        }

        planExercise.plannedSetCount = existingSets.count
    }

    private func updateSets(_ newSets: [SetInputData]) {
        let resolvedSets = normalizeSetsIfNeeded(newSets)

        // Remove existing sets
        let existingSets = planExercise.sortedPlannedSets
        for set in existingSets {
            planExercise.removePlannedSet(set)
        }

        // Add new sets with all metric type fields including rest time
        for setData in resolvedSets {
            let weight: Double? = setData.metricType == .bodyweightReps ? nil : setData.weight
            planExercise.createPlannedSet(
                metricType: setData.metricType,
                weight: weight,
                reps: setData.reps,
                durationSeconds: setData.durationSeconds,
                distanceMeters: setData.distanceMeters,
                restTimeSeconds: setData.restTimeSeconds
            )
        }

        if let locked = lockedSetCount {
            planExercise.plannedSetCount = locked
        } else {
            planExercise.plannedSetCount = resolvedSets.count
        }
    }

    private func normalizeSetsIfNeeded(_ sets: [SetInputData]) -> [SetInputData] {
        guard let locked = lockedSetCount else { return sets }
        if sets.count == locked { return sets }
        if sets.count > locked { return Array(sets.prefix(locked)) }
        // Pad with last set values to keep count consistent
        let padSource = sets.last ?? SetInputData(metricType: planExercise.metricType, weight: 60, reps: 10)
        return sets + Array(repeating: padSource, count: locked - sets.count)
    }
}
