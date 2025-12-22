//
//  CycleListView.swift
//  Routyra
//
//  List of plan cycles with add/edit/activate functionality.
//

import SwiftUI
import SwiftData

struct CycleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanCycle.createdAt, order: .reverse) private var cycles: [PlanCycle]

    @State private var profile: LocalProfile?
    @State private var showNewCycleAlert: Bool = false
    @State private var newCycleName: String = ""
    @State private var selectedCycle: PlanCycle?

    private var profileCycles: [PlanCycle] {
        guard let profileId = profile?.id else { return [] }
        return cycles.filter { $0.profileId == profileId }
    }

    var body: some View {
        NavigationStack {
            List {
                if profileCycles.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.textMuted)

                            Text("cycle_empty_title")
                                .font(.headline)
                                .foregroundColor(AppColors.textSecondary)

                            Text("cycle_empty_description")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(profileCycles) { cycle in
                            CycleRowView(
                                cycle: cycle,
                                isActive: cycle.isActive,
                                onActivate: {
                                    activateCycle(cycle)
                                },
                                onDeactivate: {
                                    deactivateCycle(cycle)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCycle = cycle
                            }
                        }
                        .onDelete(perform: deleteCycles)
                    } header: {
                        Text("cycle_list_title")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("cycle_navigation_title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newCycleName = ""
                        showNewCycleAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("cycle_new_title", isPresented: $showNewCycleAlert) {
                TextField("cycle_name_placeholder", text: $newCycleName)
                Button("cancel", role: .cancel) {}
                Button("create") {
                    createCycle()
                }
                .disabled(newCycleName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("cycle_name_required")
            }
            .navigationDestination(item: $selectedCycle) { cycle in
                CycleEditorView(cycle: cycle)
            }
            .onAppear {
                profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            }
        }
    }

    private func createCycle() {
        guard let profile = profile,
              !newCycleName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        CycleService.createCycle(
            profileId: profile.id,
            name: newCycleName.trimmingCharacters(in: .whitespaces),
            modelContext: modelContext
        )
    }

    private func activateCycle(_ cycle: PlanCycle) {
        guard let profile = profile else { return }
        CycleService.setActiveCycle(cycle, profileId: profile.id, modelContext: modelContext)
    }

    private func deactivateCycle(_ cycle: PlanCycle) {
        CycleService.deactivateCycle(cycle)
    }

    private func deleteCycles(at offsets: IndexSet) {
        for index in offsets {
            let cycle = profileCycles[index]
            CycleService.deleteCycle(cycle, modelContext: modelContext)
        }
    }
}

// MARK: - Cycle Row View

private struct CycleRowView: View {
    let cycle: PlanCycle
    let isActive: Bool
    let onActivate: () -> Void
    let onDeactivate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(cycle.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if isActive {
                        Text("active")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }

                Text(L10n.tr("cycle_plan_count", cycle.planCount))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button {
                if isActive {
                    onDeactivate()
                } else {
                    onActivate()
                }
            } label: {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? AppColors.accentBlue : AppColors.textMuted)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CycleListView()
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
        .preferredColorScheme(.dark)
}
