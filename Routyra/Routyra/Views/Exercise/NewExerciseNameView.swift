//
//  NewExerciseNameView.swift
//  Routyra
//
//  View for entering the name of a new exercise.
//

import SwiftUI
import SwiftData

struct NewExerciseNameView: View {
    let profile: LocalProfile
    let bodyPart: BodyPart
    let onCreated: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseName: String = ""
    @State private var errorMessage: String?
    @State private var isShowingError: Bool = false
    @State private var isSaving: Bool = false

    @FocusState private var isNameFieldFocused: Bool

    private var isSaveDisabled: Bool {
        exerciseName.trimmed.isEmpty || isSaving
    }

    var body: some View {
        Form {
            Section {
                TextField("exercise_name_placeholder", text: $exerciseName)
                    .focused($isNameFieldFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        if !isSaveDisabled {
                            saveExercise()
                        }
                    }
            } header: {
                Text("exercise_name_section_title")
            } footer: {
                Text(L10n.tr("exercise_body_part_label", bodyPart.localizedName))
                    .foregroundColor(AppColors.textMuted)
            }

            if let errorMessage = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .navigationTitle("exercise_new_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("save") {
                    saveExercise()
                }
                .disabled(isSaveDisabled)
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
        .alert("error_title", isPresented: $isShowingError) {
            Button("ok", role: .cancel) { }
        } message: {
            Text(errorMessage ?? L10n.tr("error_unknown"))
        }
    }

    private func saveExercise() {
        // Clear previous error
        errorMessage = nil
        isSaving = true

        do {
            let exercise = try ExerciseCreationService.createUserExercise(
                profile: profile,
                bodyPart: bodyPart,
                name: exerciseName,
                modelContext: modelContext
            )

            // Success - notify parent and dismiss
            onCreated(exercise)
            dismiss()
        } catch let error as ExerciseCreationError {
            // Show domain error
            errorMessage = error.localizedDescription

            // For duplicate error, also show alert
            if case .duplicateExercise = error {
                isShowingError = true
            }
        } catch {
            // Unexpected error
            errorMessage = L10n.tr("exercise_save_failed", error.localizedDescription)
            isShowingError = true
        }

        isSaving = false
    }
}

#Preview {
    let bodyPart = BodyPart.systemBodyPart(code: "chest", defaultName: "Chest", sortOrder: 1)

    return NavigationStack {
        NewExerciseNameView(
            profile: LocalProfile(),
            bodyPart: bodyPart,
            onCreated: { exercise in
                print("Created: \(exercise.localizedName)")
            }
        )
    }
    .modelContainer(for: [LocalProfile.self, BodyPart.self, BodyPartTranslation.self, Exercise.self, ExerciseTranslation.self], inMemory: true)
    .preferredColorScheme(.dark)
}
