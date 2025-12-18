//
//  WorkoutExercisePickerView.swift
//  Routyra
//
//  Exercise picker for adding exercises to a workout (free mode).
//  Shows existing exercises grouped by body part with search and filter.
//

import SwiftUI
import SwiftData

struct WorkoutExercisePickerView: View {
    let profile: LocalProfile
    let exercises: [UUID: Exercise]
    let bodyParts: [UUID: BodyPart]
    let onSelect: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var allExercises: [Exercise] = []
    @State private var allBodyParts: [BodyPart] = []
    @State private var searchText: String = ""
    @State private var selectedBodyPartId: UUID?

    private var filteredExercises: [Exercise] {
        var result = allExercises

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
        return allBodyParts.compactMap { bodyPart in
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
                    Section {
                        ForEach(exercises, id: \.id) { exercise in
                            Button {
                                onSelect(exercise)
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
                    } header: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(bodyPart?.color ?? Color.gray)
                                .frame(width: 10, height: 10)

                            Text(bodyPart?.localizedName ?? "その他")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .textCase(nil)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppColors.background)
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .searchable(text: $searchText, prompt: "種目を検索")
        }
        .navigationTitle("種目を追加")
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
                FilterChipView(
                    title: "すべて",
                    isSelected: selectedBodyPartId == nil
                ) {
                    selectedBodyPartId = nil
                }

                // Body part filters
                ForEach(allBodyParts, id: \.id) { bodyPart in
                    FilterChipView(
                        title: bodyPart.localizedName,
                        color: bodyPart.color,
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
        allBodyParts = ExerciseCreationService.fetchBodyParts(for: profile, modelContext: modelContext)

        // Load exercises
        allExercises = PlanService.getAvailableExercises(
            profileId: profile.id,
            modelContext: modelContext
        )
    }
}

// MARK: - Filter Chip View

private struct FilterChipView: View {
    let title: String
    var color: Color? = nil
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
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
        WorkoutExercisePickerView(
            profile: LocalProfile(),
            exercises: [:],
            bodyParts: [:],
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
