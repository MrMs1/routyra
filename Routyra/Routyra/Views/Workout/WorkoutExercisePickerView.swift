//
//  WorkoutExercisePickerView.swift
//  Routyra
//
//  Exercise picker for adding/changing exercises in a workout.
//  Card-based UI with body part filtering and search.
//  Uses shared components from ExercisePickerComponents.
//

import SwiftUI
import SwiftData

/// Mode for the exercise picker - either adding a new exercise or changing an existing one
enum ExercisePickerMode {
    case add
    case change(currentExerciseId: UUID)

    var navigationTitle: String {
        switch self {
        case .add:
            return L10n.tr("add_exercise")
        case .change:
            return L10n.tr("workout_change_exercise_title")
        }
    }
}

struct WorkoutExercisePickerView: View {
    let profile: LocalProfile
    let exercises: [UUID: Exercise]
    let bodyParts: [UUID: BodyPart]
    var mode: ExercisePickerMode = .add
    let onSelect: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var allExercises: [Exercise] = []
    @State private var allBodyParts: [BodyPart] = []
    @State private var searchText: String = ""
    @State private var selectedBodyPartId: UUID?

    /// ID of the cardio body part (used to exclude cardio when needed)
    private var cardioBodyPartId: UUID? {
        allBodyParts.first { $0.code == "cardio" }?.id
    }

    private var includeCardioExercises: Bool {
        if case .add = mode {
            return true
        }
        return false
    }

    private var filteredExercises: [Exercise] {
        var result = allExercises

        // Exclude cardio exercises when not adding
        if !includeCardioExercises, let cardioId = cardioBodyPartId {
            result = result.filter { $0.bodyPartId != cardioId }
        }

        // Filter by body part
        if let bodyPartId = selectedBodyPartId {
            result = result.filter { $0.bodyPartId == bodyPartId }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.localizedName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { $0.localizedName < $1.localizedName }
    }

    /// Returns the current exercise ID if in change mode
    private var currentExerciseId: UUID? {
        if case .change(let id) = mode {
            return id
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            ExercisePickerSearchBar(text: $searchText)

            // Body part filter
            bodyPartFilterBar

            // Exercise cards
            ScrollView {
                LazyVStack(spacing: 10) {
                    // Create new exercise card
                    NavigationLink(value: ExercisePickerDestination.newExercise) {
                        CreateExerciseCard()
                    }
                    .buttonStyle(.plain)

                    // Exercise cards
                    ForEach(filteredExercises, id: \.id) { exercise in
                        let bodyPart = exercise.bodyPartId.flatMap { id in
                            allBodyParts.first { $0.id == id }
                        }
                        let isCurrentSelection = currentExerciseId == exercise.id

                        ExerciseCardRow(
                            exerciseName: exercise.localizedName,
                            bodyPartName: bodyPart?.localizedName,
                            bodyPartColor: bodyPart?.color,
                            isCustom: exercise.scope == .user,
                            isSelected: isCurrentSelection,
                            onTap: {
                                onSelect(exercise)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppColors.background)
        }
        .background(AppColors.background)
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ExercisePickerDestination.self) { destination in
            switch destination {
            case .newExercise:
                NewExerciseFlowView(
                    profile: profile,
                    onCreated: { exercise in
                        onSelect(exercise)
                    }
                )
            }
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - Body Part Filter Bar

    private var bodyPartFilterBar: some View {
        BodyPartFilterBar(
            bodyParts: allBodyParts,
            selectedBodyPartId: $selectedBodyPartId,
            includeCardio: includeCardioExercises
        )
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load body parts
        ExerciseCreationService.seedSystemBodyPartsIfNeeded(modelContext: modelContext)
        allBodyParts = ExerciseCreationService.fetchBodyParts(for: profile, modelContext: modelContext)

        // Load exercises
        allExercises = PlanService.getAvailableExercises(
            profileId: profile.id,
            modelContext: modelContext
        )
    }
}

#Preview {
    NavigationStack {
        WorkoutExercisePickerView(
            profile: LocalProfile(),
            exercises: [:],
            bodyParts: [:],
            onSelect: { _ in }
        )
        .modelContainer(for: [
            LocalProfile.self,
            BodyPart.self,
            BodyPartTranslation.self,
            Exercise.self,
            ExerciseTranslation.self
        ], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
