//
//  CycleEditorView.swift
//  Routyra
//
//  Editor for a plan cycle. Allows name editing and plan management.
//

import SwiftUI
import SwiftData

struct CycleEditorView: View {
    @Bindable var cycle: PlanCycle

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showPlanPicker: Bool = false
    @State private var items: [PlanCycleItem] = []

    var body: some View {
        List {
            // Cycle info section
            Section {
                TextField("サイクル名", text: $cycle.name)
                    .foregroundColor(AppColors.textPrimary)
            } header: {
                Text("サイクル情報")
            }

            // Current progress section (if active)
            if cycle.isActive, let progress = cycle.progress {
                Section {
                    HStack {
                        Text("現在のプラン")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(progress.currentItemIndex + 1) / \(items.count)")
                            .foregroundColor(AppColors.textPrimary)
                    }

                    HStack {
                        Text("現在のDay")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("Day \(progress.currentDayIndex + 1)")
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Button {
                        CycleService.resetProgress(for: cycle)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("進捗をリセット")
                        }
                        .foregroundColor(.orange)
                    }
                } header: {
                    Text("進捗状況")
                }
            }

            // Plans section
            Section {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Text("プランがありません")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Text("プランを追加してサイクルを構成してください")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(items) { item in
                        CycleItemRowView(item: item, modelContext: modelContext)
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)
                }

                Button {
                    showPlanPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("プランを追加")
                    }
                    .foregroundColor(AppColors.accentBlue)
                }
            } header: {
                HStack {
                    Text("プラン")
                    Spacer()
                    if !items.isEmpty {
                        Text("\(items.count)プラン")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(cycle.name.isEmpty ? "サイクル編集" : cycle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $showPlanPicker) {
            CyclePlanPickerView(cycle: cycle) {
                syncItems()
            }
        }
        .onAppear {
            syncItems()
        }
    }

    private func syncItems() {
        items = cycle.sortedItems
        // Load plans for display
        CycleService.loadPlans(for: items, modelContext: modelContext)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            CycleService.removeItem(item, from: cycle, modelContext: modelContext)
        }
        syncItems()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        CycleService.moveItems(in: cycle, fromOffsets: source, toOffset: destination)
        syncItems()
    }
}

// MARK: - Cycle Item Row View

private struct CycleItemRowView: View {
    let item: PlanCycleItem
    let modelContext: ModelContext

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                if let plan = item.plan {
                    Text("\(plan.dayCount)日間 / \(plan.totalExerciseCount)種目")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text("プランが見つかりません")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Text("\(item.order + 1)")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 24, height: 24)
                .background(AppColors.cardBackground)
                .cornerRadius(12)
        }
        .padding(.vertical, 2)
        .onAppear {
            // Load plan if needed
            if item.plan == nil {
                item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
            }
        }
    }
}

#Preview {
    NavigationStack {
        let cycle = PlanCycle(profileId: UUID(), name: "メインサイクル")

        CycleEditorView(cycle: cycle)
            .modelContainer(for: [
                LocalProfile.self,
                PlanCycle.self,
                PlanCycleItem.self,
                PlanCycleProgress.self,
                WorkoutPlan.self,
                PlanDay.self,
                PlanExercise.self,
                PlannedSet.self
            ], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
