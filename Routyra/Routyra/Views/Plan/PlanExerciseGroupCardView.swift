//
//  PlanExerciseGroupCardView.swift
//  Routyra
//
//  Group header card for exercise group display in plan editor.
//  Shows group label, set count, rest time, and provides group management actions.
//

import SwiftUI
import SwiftData

struct PlanExerciseGroupCardView: View {
    let group: PlanExerciseGroup
    let exercisesMap: [UUID: Exercise]
    let bodyPartsMap: [UUID: BodyPart]
    let onDissolve: () -> Void
    let onUpdateSetCount: (Int) -> Void
    let onUpdateRest: (Int?) -> Void

    @State private var showSetCountEditor = false
    @State private var showRestEditor = false
    @State private var editedSetCount: Int = 3
    @State private var editedRestMinutes: Int = 0
    @State private var editedRestSeconds: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 12) {
                // Group badge
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                        .font(.caption)
                    Text(group.displayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(AppColors.accentBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.accentBlue.opacity(0.15))
                .cornerRadius(6)

                Spacer()

                // Set count
                Button {
                    editedSetCount = group.setCount
                    showSetCountEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.tr("group_set_count", group.setCount))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .buttonStyle(.plain)

                // Context menu
                Menu {
                    Button(role: .destructive) {
                        onDissolve()
                    } label: {
                        Label(L10n.tr("dissolve_group"), systemImage: "rectangle.stack.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Rest time row
            HStack {
                Text(L10n.tr("group_round_rest"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Button {
                    if let rest = group.roundRestSeconds {
                        editedRestMinutes = rest / 60
                        editedRestSeconds = rest % 60
                    } else {
                        editedRestMinutes = 1
                        editedRestSeconds = 30
                    }
                    showRestEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Text(formatRestTime(group.roundRestSeconds))
                            .font(.caption)
                            .foregroundColor(AppColors.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .sheet(isPresented: $showSetCountEditor) {
            GroupSetCountEditorSheet(
                setCount: $editedSetCount,
                onSave: {
                    onUpdateSetCount(editedSetCount)
                }
            )
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showRestEditor) {
            GroupRestEditorSheet(
                minutes: $editedRestMinutes,
                seconds: $editedRestSeconds,
                onSave: {
                    let total = editedRestMinutes * 60 + editedRestSeconds
                    onUpdateRest(total > 0 ? total : nil)
                }
            )
            .presentationDetents([.height(250)])
        }
    }

    private func formatRestTime(_ seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else {
            return L10n.tr("none")
        }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        } else if mins > 0 {
            return "\(mins):00"
        } else {
            return "0:\(String(format: "%02d", secs))"
        }
    }
}

// MARK: - Set Count Editor Sheet

private struct GroupSetCountEditorSheet: View {
    @Binding var setCount: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(L10n.tr("group_set_count", setCount))
                    .font(.title2.weight(.semibold))

                Stepper(value: $setCount, in: 1...20) {
                    EmptyView()
                }
                .labelsHidden()
                .frame(width: 120)

                Spacer()
            }
            .padding(.top, 30)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("set_count"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("save")) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Rest Editor Sheet

private struct GroupRestEditorSheet: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    VStack {
                        Picker("", selection: $minutes) {
                            ForEach(0...10, id: \.self) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text(L10n.tr("rest_time_minutes"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    VStack {
                        Picker("", selection: $seconds) {
                            ForEach([0, 15, 30, 45], id: \.self) { sec in
                                Text("\(sec)").tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text(L10n.tr("rest_time_seconds"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("group_round_rest"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("save")) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}
