//
//  GroupRoundView.swift
//  Routyra Watch App Watch App
//
//  Displays grouped exercises for the active round.
//  Users record each exercise in the round; rest starts only when the round completes.
//

import SwiftUI

struct GroupRoundView: View {
    let group: WatchExerciseGroupData
    let activeRound: Int
    @ObservedObject var themeManager: WatchThemeManager
    /// Called when the whole round is recorded (group spec).
    let onLogRound: () -> Void

    private var sortedExercises: [WatchExerciseData] {
        group.exercises.sorted { ($0.groupOrderIndex ?? 0) < ($1.groupOrderIndex ?? 0) }
    }

    private var canLogRound: Bool {
        let index = max(activeRound - 1, 0)
        for exercise in sortedExercises {
            let sortedSets = exercise.sets.sorted { $0.setIndex < $1.setIndex }
            guard index < sortedSets.count else { continue }
            if !sortedSets[index].isCompleted {
                return true
            }
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header (scrolls with content)
                VStack(spacing: 4) {
                    Text("グループ")
                        .font(.headline)
                        .foregroundColor(themeManager.textPrimary)

                    Text("ラウンド \(activeRound)/\(max(group.setCount, 1))")
                        .font(.caption)
                        .foregroundColor(themeManager.textSecondary)
                }

                // Exercise list
                VStack(spacing: 8) {
                    ForEach(sortedExercises) { exercise in
                        GroupRoundRowView(
                            exercise: exercise,
                            round: activeRound,
                            themeManager: themeManager
                        )
                    }
                }
                .padding(.bottom, 12) // space before bottom button
            }
            .padding(.horizontal, 8)
        }
        // Bottom action button pinned to the bottom to maximize scroll area
        .safeAreaInset(edge: .bottom) {
            Button(action: onLogRound) {
                Text("記録")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(canLogRound ? themeManager.accentBlue : themeManager.cardBackground)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!canLogRound)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 1)
        }
    }
}

private struct GroupRoundRowView: View {
    let exercise: WatchExerciseData
    let round: Int
    @ObservedObject var themeManager: WatchThemeManager

    private var sortedSets: [WatchSetData] {
        exercise.sets.sorted { $0.setIndex < $1.setIndex }
    }

    private var setForRound: WatchSetData? {
        let index = max(round - 1, 0)
        guard index < sortedSets.count else { return nil }
        return sortedSets[index]
    }

    private var setDescription: String {
        guard let set = setForRound else { return "--" }
        switch exercise.metricType {
        case "weightReps":
            let weight = set.weight ?? 0
            let reps = set.reps ?? 0
            let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", weight)
                : String(format: "%.1f", weight)
            return "\(weightStr)kg × \(reps)"
        case "bodyweightReps":
            let reps = set.reps ?? 0
            return "× \(reps)"
        case "timeDistance":
            if let duration = set.durationSeconds {
                let mins = duration / 60
                let secs = duration % 60
                return String(format: "%d:%02d", mins, secs)
            }
            return "--:--"
        case "completion":
            return "Complete"
        default:
            return "--"
        }
    }

    private var bodyPartColor: Color {
        themeManager.bodyPartColor(for: exercise.bodyPartCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(bodyPartColor)
                    .frame(width: 8, height: 8)

                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 4)

                if let set = setForRound, set.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.successGreen)
                }
            }

            HStack(spacing: 8) {
                Text(setDescription)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(themeManager.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
        }
        .padding(10)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    let sets = [
        WatchSetData(id: UUID(), setIndex: 1, weight: 60, reps: 8, durationSeconds: nil, distanceMeters: nil, restTimeSeconds: nil, isCompleted: false),
        WatchSetData(id: UUID(), setIndex: 2, weight: 60, reps: 8, durationSeconds: nil, distanceMeters: nil, restTimeSeconds: nil, isCompleted: false)
    ]
    let ex1 = WatchExerciseData(id: UUID(), exerciseId: UUID(), name: "Bench", orderIndex: 0, groupOrderIndex: 0, metricType: "weightReps", bodyPartCode: "chest", sets: sets)
    let ex2 = WatchExerciseData(id: UUID(), exerciseId: UUID(), name: "Row", orderIndex: 1, groupOrderIndex: 1, metricType: "weightReps", bodyPartCode: "back", sets: sets)
    let group = WatchExerciseGroupData(id: UUID(), orderIndex: 0, setCount: 2, roundRestSeconds: 90, exercises: [ex1, ex2])
    return GroupRoundView(
        group: group,
        activeRound: 1,
        themeManager: WatchThemeManager.shared,
        onLogRound: {}
    )
}

