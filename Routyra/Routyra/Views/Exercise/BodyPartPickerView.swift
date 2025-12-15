//
//  BodyPartPickerView.swift
//  Routyra
//
//  View for selecting a body part when creating a new exercise.
//  Also allows creating new body parts.
//

import SwiftUI
import SwiftData

struct BodyPartPickerView: View {
    let profile: LocalProfile
    let onSelect: (BodyPart) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var bodyParts: [BodyPart] = []
    @State private var searchText: String = ""
    @State private var showNewBodyPartSheet: Bool = false

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
            ForEach(filteredBodyParts, id: \.id) { bodyPart in
                Button {
                    onSelect(bodyPart)
                } label: {
                    HStack {
                        Text(bodyPart.localizedName)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        if bodyPart.scope == .user {
                            Text("カスタム")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "部位を検索")
        .navigationTitle("部位を選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewBodyPartSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadBodyParts()
        }
        .sheet(isPresented: $showNewBodyPartSheet) {
            NewBodyPartView(profile: profile) { newBodyPart in
                // Refresh the list after creation
                loadBodyParts()

                // Optionally auto-select the new body part
                // Uncomment the line below to auto-select:
                // onSelect(newBodyPart)
            }
        }
    }

    private func loadBodyParts() {
        ExerciseCreationService.seedSystemBodyPartsIfNeeded(modelContext: modelContext)
        bodyParts = ExerciseCreationService.fetchBodyParts(for: profile, modelContext: modelContext)
    }
}

#Preview {
    NavigationStack {
        BodyPartPickerView(
            profile: LocalProfile(),
            onSelect: { _ in }
        )
    }
    .modelContainer(for: [LocalProfile.self, BodyPart.self, Exercise.self], inMemory: true)
    .preferredColorScheme(.dark)
}
