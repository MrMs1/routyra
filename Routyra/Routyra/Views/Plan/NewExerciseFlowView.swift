//
//  NewExerciseFlowView.swift
//  Routyra
//
//  Push-based flow for creating a new exercise.
//  Works as a child of existing NavigationStack.
//  Two-step flow: 1) Select body part, 2) Enter exercise name.
//

import SwiftUI
import SwiftData

/// Navigation destination for new exercise flow
enum NewExerciseFlowDestination: Hashable {
    case exerciseName(bodyPartId: UUID)
}

struct NewExerciseFlowView: View {
    let profile: LocalProfile
    let onCreated: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bodyParts: [BodyPart] = []
    @State private var searchText: String = ""

    private var filteredBodyParts: [BodyPart] {
        if searchText.isEmpty {
            return bodyParts
        }
        return bodyParts.filter {
            $0.localizedName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filteredBodyParts, id: \.id) { bodyPart in
                    NavigationLink(value: NewExerciseFlowDestination.exerciseName(bodyPartId: bodyPart.id)) {
                        HStack {
                            Text(bodyPart.localizedName)
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if bodyPart.scope == .user {
                                Text("exercise_custom_badge")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }
                    }
                }
            } header: {
                Text("body_part_select_title")
            }
        }
        .searchable(text: $searchText, prompt: "body_part_search_placeholder")
        .navigationTitle("exercise_create_new")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NewExerciseFlowDestination.self) { destination in
            switch destination {
            case .exerciseName(let bodyPartId):
                if let bodyPart = bodyParts.first(where: { $0.id == bodyPartId }) {
                    NewExerciseNameInputView(
                        profile: profile,
                        bodyPart: bodyPart,
                        onCreated: { exercise in
                            onCreated(exercise)
                            // Pop back to PlanEditorView (multiple pops handled by parent)
                        }
                    )
                }
            }
        }
        .onAppear {
            loadBodyParts()
        }
    }

    private func loadBodyParts() {
        ExerciseCreationService.seedSystemBodyPartsIfNeeded(modelContext: modelContext)
        bodyParts = ExerciseCreationService.fetchBodyParts(for: profile, modelContext: modelContext)
    }
}

// MARK: - Exercise Name Input View

struct NewExerciseNameInputView: View {
    let profile: LocalProfile
    let bodyPart: BodyPart
    let onCreated: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseName: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    private var canSave: Bool {
        !exerciseName.trimmed.isEmpty && !isSaving
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("body_part")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(bodyPart.localizedName)
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            Section {
                TextField("exercise_name_placeholder", text: $exerciseName)
                    .focused($isNameFocused)
                    .foregroundColor(AppColors.textPrimary)
                    .autocorrectionDisabled()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("exercise_name")
            } footer: {
                Text("exercise_name_example")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .navigationTitle("exercise_name_section_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("create") {
                    createExercise()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            isNameFocused = true
        }
    }

    private func createExercise() {
        isSaving = true
        errorMessage = nil

        do {
            let exercise = try ExerciseCreationService.createUserExercise(
                profile: profile,
                bodyPart: bodyPart,
                name: exerciseName,
                modelContext: modelContext
            )
            onCreated(exercise)
            dismiss()
        } catch let error as ExerciseCreationError {
            errorMessage = error.errorDescription
            isSaving = false
        } catch {
            errorMessage = L10n.tr("exercise_create_failed")
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        NewExerciseFlowView(
            profile: LocalProfile(),
            onCreated: { exercise in
                print("Created: \(exercise.localizedName)")
            }
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
