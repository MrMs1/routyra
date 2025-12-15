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
                TextField("エクササイズ名", text: $exerciseName)
                    .focused($isNameFieldFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        if !isSaveDisabled {
                            saveExercise()
                        }
                    }
            } header: {
                Text("エクササイズ名を入力")
            } footer: {
                Text("部位: \(bodyPart.name)")
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
        .navigationTitle("新しいエクササイズ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveExercise()
                }
                .disabled(isSaveDisabled)
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
        .alert("エラー", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました")
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
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
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
