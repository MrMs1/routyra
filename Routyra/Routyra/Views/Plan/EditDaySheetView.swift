//
//  EditDaySheetView.swift
//  Routyra
//
//  Minimal sheet for editing a PlanDay's title.
//  Cancel discards changes, Done saves with trimmed whitespace.
//

import SwiftUI

struct EditDaySheetView: View {
    let dayIndex: Int
    let currentTitle: String?
    let onSave: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draftTitle: String = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("day_title_example", text: $draftTitle)
                        .focused($isTitleFocused)
                } header: {
                    Text("day_title")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("day_edit_title", dayIndex))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(false)
        }
        .onAppear {
            draftTitle = currentTitle ?? ""
            // Auto-focus after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTitleFocused = true
            }
        }
    }

    private func saveAndDismiss() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle: String? = trimmed.isEmpty ? nil : trimmed
        onSave(newTitle)
        dismiss()
    }
}

#Preview {
    EditDaySheetView(
        dayIndex: 1,
        currentTitle: "Push",
        onSave: { _ in }
    )
    .preferredColorScheme(.dark)
}
