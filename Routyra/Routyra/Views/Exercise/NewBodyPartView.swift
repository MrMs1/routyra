//
//  NewBodyPartView.swift
//  Routyra
//
//  View for creating a new body part.
//

import SwiftUI
import SwiftData

struct NewBodyPartView: View {
    let profile: LocalProfile
    let onCreated: (BodyPart) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bodyPartName: String = ""
    @State private var errorMessage: String?
    @State private var isShowingError: Bool = false
    @State private var isSaving: Bool = false

    @FocusState private var isNameFieldFocused: Bool

    private var isSaveDisabled: Bool {
        bodyPartName.trimmed.isEmpty || isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("部位名", text: $bodyPartName)
                        .focused($isNameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            if !isSaveDisabled {
                                saveBodyPart()
                            }
                        }
                } header: {
                    Text("部位名を入力")
                } footer: {
                    Text("例: 前腕、ふくらはぎ、首")
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
            .navigationTitle("新しい部位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveBodyPart()
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
    }

    private func saveBodyPart() {
        // Clear previous error
        errorMessage = nil
        isSaving = true

        do {
            let bodyPart = try BodyPartCreationService.createUserBodyPart(
                profile: profile,
                name: bodyPartName,
                modelContext: modelContext
            )

            // Success - notify parent and dismiss
            onCreated(bodyPart)
            dismiss()
        } catch let error as BodyPartCreationError {
            // Show domain error
            errorMessage = error.localizedDescription

            // For duplicate error, also show alert
            if case .duplicateBodyPart = error {
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
    NewBodyPartView(
        profile: LocalProfile(),
        onCreated: { bodyPart in
            print("Created: \(bodyPart.name)")
        }
    )
    .modelContainer(for: [LocalProfile.self, BodyPart.self], inMemory: true)
    .preferredColorScheme(.dark)
}
