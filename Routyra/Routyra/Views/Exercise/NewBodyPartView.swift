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
                    TextField("body_part_name_placeholder", text: $bodyPartName)
                        .focused($isNameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            if !isSaveDisabled {
                                saveBodyPart()
                            }
                        }
                } header: {
                    Text("body_part_name_section_title")
                } footer: {
                    Text("body_part_name_example")
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
            .navigationTitle("body_part_new_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        saveBodyPart()
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
            errorMessage = L10n.tr("body_part_save_failed", error.localizedDescription)
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
