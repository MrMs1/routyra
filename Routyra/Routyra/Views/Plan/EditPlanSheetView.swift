//
//  EditPlanSheetView.swift
//  Routyra
//
//  Sheet for editing WorkoutPlan name and memo.
//  Cancel discards changes, Done saves with trimmed whitespace.
//

import SwiftUI

struct EditPlanSheetView: View {
    let currentName: String
    let currentNote: String?
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String = ""
    @State private var draftNote: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case note
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例: Push/Pull", text: $draftName)
                        .focused($focusedField, equals: .name)
                } header: {
                    Text("プラン名")
                }

                Section {
                    TextField("例: 週3回のトレーニングプラン", text: $draftNote, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .note)
                } header: {
                    Text("メモ（任意）")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("プランを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(false)
        }
        .onAppear {
            draftName = currentName
            draftNote = currentNote ?? ""
            // Auto-focus name field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .name
            }
        }
    }

    private func saveAndDismiss() {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let note: String? = trimmedNote.isEmpty ? nil : trimmedNote
        onSave(trimmedName, note)
        dismiss()
    }
}

#Preview {
    EditPlanSheetView(
        currentName: "Push Pull Legs",
        currentNote: "週3回のプラン",
        onSave: { _, _ in }
    )
    .preferredColorScheme(.dark)
}
