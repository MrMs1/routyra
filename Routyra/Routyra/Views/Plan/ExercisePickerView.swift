//
//  ExercisePickerView.swift
//  Routyra
//
//  View for selecting an exercise when adding to a plan day.
//  Works as a push destination within NavigationStack (no modals).
//  Shows existing exercises grouped by body part, with option to create new.
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
    let onSelect: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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

        return result
    }

    private var groupedExercises: [(BodyPart?, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.bodyPartId }
        return bodyParts.compactMap { bodyPart in
            if let exercises = grouped[bodyPart.id], !exercises.isEmpty {
                return (bodyPart, exercises)
            }
            return nil
        } + (grouped[nil] != nil ? [(nil, grouped[nil]!)] : [])
    }

    var body: some View {
        VStack(spacing: 0) {
            // Body part filter
            bodyPartFilterBar

            // Exercise list
            List {
                // Create new option
                Section {
                    NavigationLink(value: ExercisePickerDestination.newExercise) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppColors.accentBlue)
                            Text("新しい種目を作成")
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }
                }

                // Existing exercises
                ForEach(groupedExercises, id: \.0?.id) { (bodyPart, exercises) in
                    Section(header: Text(bodyPart?.localizedName ?? "その他")) {
                        ForEach(exercises, id: \.id) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(exercise.localizedName)
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    if exercise.scope == .user {
                                        Text("カスタム")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textMuted)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "種目を検索")
        }
        .navigationTitle("\(dayTitle)に追加")
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All filter
                FilterChip(
                    title: "すべて",
                    isSelected: selectedBodyPartId == nil
                ) {
                    selectedBodyPartId = nil
                }

                // Body part filters
                ForEach(bodyParts, id: \.id) { bodyPart in
                    FilterChip(
                        title: bodyPart.localizedName,
                        isSelected: selectedBodyPartId == bodyPart.id
                    ) {
                        selectedBodyPartId = bodyPart.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(AppColors.cardBackground)
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load body parts
        ExerciseCreationService.seedSystemBodyPartsIfNeeded(modelContext: modelContext)
        bodyParts = ExerciseCreationService.fetchBodyParts(for: profile, modelContext: modelContext)

        // Load exercises
        exercises = PlanService.getAvailableExercises(
            profileId: profile.id,
            modelContext: modelContext
        )
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.accentBlue : AppColors.background)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ExercisePickerView(
            profile: LocalProfile(),
            dayTitle: "Day 1 - Push",
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
