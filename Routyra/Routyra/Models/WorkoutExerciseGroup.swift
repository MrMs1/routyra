//
//  WorkoutExerciseGroup.swift
//  Routyra
//
//  Represents a group of exercise entries within a workout.
//  All entries in a group are performed as rounds (one set per exercise = one round).
//  Group structure is immutable during workout (inherited from plan).
//

import Foundation
import SwiftData

@Model
final class WorkoutExerciseGroup {
    /// Unique identifier.
    var id: UUID

    /// Parent workout day (relationship).
    var workoutDay: WorkoutDay?

    /// Display order within the workout day (0-indexed).
    /// Used alongside ungrouped entries' orderIndex for unified ordering.
    var orderIndex: Int

    /// Number of rounds (sets per exercise) for this group.
    /// Immutable during workout - inherited from plan.
    var setCount: Int

    /// Rest time after each round in seconds (optional, editable during workout).
    var roundRestSeconds: Int?

    /// Entries belonging to this group.
    /// Uses .nullify to allow entries to become ungrouped when group is deleted.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExerciseEntry.group)
    var entries: [WorkoutExerciseEntry]

    // MARK: - Initialization

    /// Creates a new workout exercise group.
    /// - Parameters:
    ///   - orderIndex: Display order within the day.
    ///   - setCount: Number of rounds.
    ///   - roundRestSeconds: Rest time after each round (optional).
    init(
        orderIndex: Int,
        setCount: Int,
        roundRestSeconds: Int? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.setCount = setCount
        self.roundRestSeconds = roundRestSeconds
        self.entries = []
    }

    // MARK: - Computed Properties

    /// Entries sorted by their group order index.
    var sortedEntries: [WorkoutExerciseEntry] {
        entries.sorted { ($0.groupOrderIndex ?? 0) < ($1.groupOrderIndex ?? 0) }
    }

    /// Number of entries in this group.
    var entryCount: Int {
        entries.count
    }

    /// Localized display name for the group.
    @MainActor
    var displayName: String {
        L10n.tr("group_label")
    }

    // MARK: - Round Progress Tracking

    /// Number of fully completed rounds.
    /// A round is complete when all entries have at least that many completed sets.
    var roundsCompleted: Int {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.completedSetsCount).min() ?? 0
    }

    /// Currently active round (1-indexed).
    /// Returns the next round to work on, capped at setCount.
    var activeRound: Int {
        min(roundsCompleted + 1, setCount)
    }

    /// Whether the current round is complete.
    /// True when all entries have completedSetsCount >= activeRound.
    var isCurrentRoundComplete: Bool {
        guard !entries.isEmpty else { return false }
        return entries.allSatisfy { $0.completedSetsCount >= activeRound }
    }

    /// Whether all rounds are complete.
    var isAllRoundsComplete: Bool {
        roundsCompleted >= setCount
    }

    /// Group progress state for UI display.
    var progressState: GroupProgressState {
        if entries.allSatisfy({ $0.completedSetsCount == 0 }) {
            return .notStarted
        } else if isAllRoundsComplete {
            return .completed
        } else {
            return .inProgress
        }
    }

    /// Next entry to focus on within this group.
    /// Returns the first entry (by groupOrderIndex) that hasn't completed the active round.
    var nextEntryToFocus: WorkoutExerciseEntry? {
        sortedEntries.first { $0.completedSetsCount < activeRound }
    }

    // MARK: - Methods

    /// Adds an entry to this group.
    /// Assigns the next available groupOrderIndex.
    func addEntry(_ entry: WorkoutExerciseEntry) {
        let nextIndex = (entries.compactMap(\.groupOrderIndex).max() ?? -1) + 1
        entry.groupOrderIndex = nextIndex
        entries.append(entry)
    }

    /// Updates the round rest time (only allowed edit during workout).
    func updateRestSeconds(_ seconds: Int?) {
        self.roundRestSeconds = seconds
    }

    /// Reindexes entries' group order after changes.
    func reindexEntries() {
        for (index, entry) in sortedEntries.enumerated() {
            entry.groupOrderIndex = index
        }
    }

    // MARK: - Private Helpers

    /// Formats rest time in seconds to a readable string.
    private func formatRestTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return secs > 0 ? String(format: "%d:%02d", minutes, secs) : "\(minutes)m"
        }
        return "\(secs)s"
    }
}

// MARK: - Group Progress State

/// Represents the progress state of a workout exercise group.
enum GroupProgressState {
    /// No sets have been completed in any entry.
    case notStarted
    /// At least one set is completed but not all rounds are done.
    case inProgress
    /// All rounds are complete.
    case completed
}
