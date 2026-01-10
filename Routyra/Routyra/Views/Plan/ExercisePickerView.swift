//
//  ExercisePickerView.swift
//  Routyra
//
//  View for selecting an exercise when adding to a plan day.
//  Card-based UI with body part filtering and search.
//  Uses shared components from ExercisePickerComponents.
//

import SwiftUI
import SwiftData

/// Navigation destination for exercise picker
enum ExercisePickerDestination: Hashable {
    case newExercise
}

struct ExercisePickerView: View {
    let profile: LocalProfile
    let dayTitle: String
    let autoDismiss: Bool
    let onSelect: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Convenience initializer with autoDismiss = true (backward compatible)
    init(profile: LocalProfile, dayTitle: String, onSelect: @escaping (Exercise) -> Void) {
        self.profile = profile
        self.dayTitle = dayTitle
        self.autoDismiss = true
        self.onSelect = onSelect
    }

    /// Full initializer with autoDismiss control
    init(profile: LocalProfile, dayTitle: String, autoDismiss: Bool, onSelect: @escaping (Exercise) -> Void) {
        self.profile = profile
        self.dayTitle = dayTitle
        self.autoDismiss = autoDismiss
        self.onSelect = onSelect
    }

    @State private var exercises: [Exercise] = []
    @State private var bodyParts: [BodyPart] = []
    @State private var searchText: String = ""
    @State private var selectedBodyPartId: UUID?

    private var filteredExercises: [Exercise] {
        var result = exercises

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
                            bodyParts.first { $0.id == id }
                        }

                        ExerciseCardRow(
                            exerciseName: exercise.localizedName,
                            bodyPartName: bodyPart?.localizedName,
                            bodyPartColor: bodyPart?.color,
                            isCustom: exercise.scope == .user,
                            onTap: {
                                onSelect(exercise)
                                if autoDismiss {
                                    dismiss()
                                }
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
        .navigationTitle(L10n.tr("plan_add_to_day", dayTitle))
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
            bodyParts: bodyParts,
            selectedBodyPartId: $selectedBodyPartId,
            includeCardio: true
        )
    }

    // MARK: - Data Loading

    private func loadData() {
        // Ensure system exercises are seeded (idempotent)
        ExerciseCreationService.seedSystemDataIfNeeded(modelContext: modelContext)
        bodyParts = ExerciseCreationService.fetchBodyParts(for: profile, modelContext: modelContext)

        // Load exercises
        exercises = PlanService.getAvailableExercises(
            profileId: profile.id,
            modelContext: modelContext
        )
    }
}

#Preview {
    NavigationStack {
        ExercisePickerView(
            profile: LocalProfile(),
            dayTitle: "Day 1",
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
