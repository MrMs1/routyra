//
//  RoutinesView.swift
//  Routyra
//
//  Main view for managing workout plans.
//  Uses NavigationStack with push navigation (no modals).
//

import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var profile: LocalProfile?
    @State private var plans: [WorkoutPlan] = []
    @State private var navigationPath = NavigationPath()
    @State private var planToDelete: WorkoutPlan?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                if plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("ワークアウトプラン")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewPlan()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(
                    plan: plan,
                    isNewPlan: plan.name.isEmpty,
                    onSave: {
                        savePlan(plan)
                        navigationPath.removeLast()
                        loadData()
                    },
                    onDiscard: {
                        discardPlan(plan)
                        navigationPath.removeLast()
                        loadData()
                    }
                )
            }
            .onAppear {
                loadData()
            }
            .alert("プランを削除", isPresented: .init(
                get: { planToDelete != nil },
                set: { if !$0 { planToDelete = nil } }
            )) {
                Button("削除", role: .destructive) {
                    if let plan = planToDelete {
                        deletePlan(plan)
                    }
                }
                Button("キャンセル", role: .cancel) {
                    planToDelete = nil
                }
            } message: {
                Text("「\(planToDelete?.name ?? "")」を削除しますか？この操作は取り消せません。")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textMuted)

            Text("プランがありません")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("ワークアウトプランを作成して\n計画的にトレーニングしましょう")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                createNewPlan()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("プランを作成")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.accentBlue)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Plan List

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Cycle section
                cycleSection

                // Plans
                ForEach(plans, id: \.id) { plan in
                    PlanCardView(
                        plan: plan,
                        isActive: profile?.activePlanId == plan.id,
                        onTap: {
                            navigationPath.append(plan)
                        },
                        onSetActive: {
                            setActivePlan(plan)
                        },
                        onDelete: {
                            planToDelete = plan
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Cycle Section

    private var cycleSection: some View {
        NavigationLink(destination: CycleListView()) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accentBlue)
                    .frame(width: 36, height: 36)
                    .background(AppColors.accentBlue.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("サイクル")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("複数のプランを順番に回す")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadData() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        guard let profile = profile else { return }

        plans = PlanService.getPlans(
            profileId: profile.id,
            modelContext: modelContext
        )
    }

    private func createNewPlan() {
        guard let profile = profile else { return }

        let plan = WorkoutPlan(profileId: profile.id, name: "")
        modelContext.insert(plan)
        navigationPath.append(plan)
    }

    private func savePlan(_ plan: WorkoutPlan) {
        plan.touch()
        try? modelContext.save()
    }

    private func discardPlan(_ plan: WorkoutPlan) {
        // If it's a new plan (no name), delete it entirely
        if plan.name.isEmpty {
            modelContext.delete(plan)
        }
        try? modelContext.save()
    }

    private func deletePlan(_ plan: WorkoutPlan) {
        // If this was the active plan, clear it
        if profile?.activePlanId == plan.id {
            profile?.activePlanId = nil
        }
        modelContext.delete(plan)
        try? modelContext.save()
        loadData()
    }

    private func setActivePlan(_ plan: WorkoutPlan) {
        guard let profile = profile else { return }

        if profile.activePlanId == plan.id {
            // Toggle off
            profile.activePlanId = nil
        } else {
            profile.activePlanId = plan.id
        }
        try? modelContext.save()
        loadData()
    }
}

// MARK: - Plan Card View

private struct PlanCardView: View {
    let plan: WorkoutPlan
    let isActive: Bool
    let onTap: () -> Void
    let onSetActive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(plan.name.isEmpty ? "新規プラン" : plan.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if isActive {
                        Text("アクティブ")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                // Summary
                HStack(spacing: 16) {
                    Label("\(plan.dayCount)日", systemImage: "calendar")
                    Label("\(plan.totalExerciseCount)種目", systemImage: "figure.strengthtraining.traditional")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

                // Note
                if let note = plan.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSetActive()
            } label: {
                Label(
                    isActive ? "アクティブを解除" : "アクティブに設定",
                    systemImage: isActive ? "star.slash" : "star.fill"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

#Preview {
    RoutinesView()
        .modelContainer(for: [
            LocalProfile.self,
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlannedSet.self,
            Exercise.self,
            BodyPart.self,
            BodyPartTranslation.self,
            ExerciseTranslation.self
        ], inMemory: true)
        .preferredColorScheme(.dark)
}
