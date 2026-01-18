//
//  WatchConnectivityManager.swift
//  Routyra Watch App Watch App
//
//  Manages Watch Connectivity session for receiving workout data from iPhone
//  and sending set completions back.
//

import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published State

    @Published private(set) var workoutData: WatchWorkoutData?
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var lastSyncDate: Date?

    // MARK: - Private Properties

    private var session: WCSession?
    private let appGroupID = "group.com.mrms.routyra"
    private let themeKey = "selectedTheme"

    // MARK: - Initialization

    private override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Public API

    /// Requests workout data sync from iPhone.
    func requestSync() {
        guard let session = session else { return }

        let message: [String: Any] = [WatchMessageKey.requestSync: true]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { @Sendable error in
                Task { @MainActor in
                    print("Error requesting sync: \(error.localizedDescription)")
                }
            }
        } else {
            // If iPhone app isn't reachable (often when not in foreground),
            // queue the request so it can be delivered later.
            session.transferUserInfo(message)
        }
    }

    /// Sends set completion to iPhone.
    func sendSetCompletion(setId: UUID) {
        guard let session = session else { return }

        let completion = WatchSetCompletionMessage(setId: setId, completedAt: Date())

        do {
            let data = try JSONEncoder().encode(completion)
            let message: [String: Any] = [WatchMessageKey.setCompletion: data]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { @Sendable error in
                    Task { @MainActor in
                        print("Error sending set completion: \(error.localizedDescription)")
                    }
                }
            } else {
                // Queue for later delivery
                session.transferUserInfo(message)
            }
        } catch {
            print("Error encoding set completion: \(error.localizedDescription)")
        }
    }

    /// Marks a set as completed locally (for immediate UI update).
    func markSetCompleted(setId: UUID) {
        guard var data = workoutData else { return }
        let now = Date()

        // Ungrouped exercises
        for i in data.exercises.indices {
            for j in data.exercises[i].sets.indices where data.exercises[i].sets[j].id == setId {
                data.exercises[i].sets[j].isCompleted = true
                data.exercises[i].sets[j].completedAt = now
                workoutData = data
                return
            }
        }

        // Grouped exercises
        for g in data.exerciseGroups.indices {
            for e in data.exerciseGroups[g].exercises.indices {
                for s in data.exerciseGroups[g].exercises[e].sets.indices
                    where data.exerciseGroups[g].exercises[e].sets[s].id == setId {
                    data.exerciseGroups[g].exercises[e].sets[s].isCompleted = true
                    data.exerciseGroups[g].exercises[e].sets[s].completedAt = now
                    workoutData = data
                    return
                }
            }
        }
    }

    /// Marks a set as not completed locally (for immediate UI update when phone reverts a set).
    func markSetUncompleted(setId: UUID) {
        guard var data = workoutData else { return }
        let now = Date()

        // Ungrouped exercises
        for i in data.exercises.indices {
            for j in data.exercises[i].sets.indices where data.exercises[i].sets[j].id == setId {
                data.exercises[i].sets[j].isCompleted = false
                data.exercises[i].sets[j].completedAt = now
                workoutData = data
                return
            }
        }

        // Grouped exercises
        for g in data.exerciseGroups.indices {
            for e in data.exerciseGroups[g].exercises.indices {
                for s in data.exerciseGroups[g].exercises[e].sets.indices
                    where data.exerciseGroups[g].exercises[e].sets[s].id == setId {
                    data.exerciseGroups[g].exercises[e].sets[s].isCompleted = false
                    data.exerciseGroups[g].exercises[e].sets[s].completedAt = now
                    workoutData = data
                    return
                }
            }
        }
    }

    // MARK: - Private Methods

    private func updateWorkoutData(_ workout: WatchWorkoutData) {
        guard let current = self.workoutData else {
            self.workoutData = workout
            self.lastSyncDate = Date()
            return
        }

        var merged = workout
        mergeSetStates(from: current, into: &merged)
        self.workoutData = merged
        self.lastSyncDate = Date()
    }

    /// Merges set completion states using timestamp-based conflict resolution.
    /// The newer `completedAt` timestamp wins; if only one side has a timestamp, that side is used.
    private func mergeSetStates(from current: WatchWorkoutData, into incoming: inout WatchWorkoutData) {
        // Build a lookup of local set states
        var localStates: [UUID: (isCompleted: Bool, completedAt: Date?)] = [:]
        for exercise in current.exercises {
            for set in exercise.sets {
                localStates[set.id] = (set.isCompleted, set.completedAt)
            }
        }
        for group in current.exerciseGroups {
            for exercise in group.exercises {
                for set in exercise.sets {
                    localStates[set.id] = (set.isCompleted, set.completedAt)
                }
            }
        }

        // Merge into incoming data (ungrouped exercises)
        for i in incoming.exercises.indices {
            for j in incoming.exercises[i].sets.indices {
                let setId = incoming.exercises[i].sets[j].id
                if let local = localStates[setId] {
                    let incomingAt = incoming.exercises[i].sets[j].completedAt
                    if shouldPreferLocal(localAt: local.completedAt, incomingAt: incomingAt) {
                        incoming.exercises[i].sets[j].isCompleted = local.isCompleted
                        incoming.exercises[i].sets[j].completedAt = local.completedAt
                    }
                }
            }
        }

        // Merge into incoming data (grouped exercises)
        for g in incoming.exerciseGroups.indices {
            for e in incoming.exerciseGroups[g].exercises.indices {
                for s in incoming.exerciseGroups[g].exercises[e].sets.indices {
                    let setId = incoming.exerciseGroups[g].exercises[e].sets[s].id
                    if let local = localStates[setId] {
                        let incomingAt = incoming.exerciseGroups[g].exercises[e].sets[s].completedAt
                        if shouldPreferLocal(localAt: local.completedAt, incomingAt: incomingAt) {
                            incoming.exerciseGroups[g].exercises[e].sets[s].isCompleted = local.isCompleted
                            incoming.exerciseGroups[g].exercises[e].sets[s].completedAt = local.completedAt
                        }
                    }
                }
            }
        }
    }

    /// Determines whether to prefer local state over incoming state based on timestamps.
    private func shouldPreferLocal(localAt: Date?, incomingAt: Date?) -> Bool {
        guard let l = localAt else { return false }  // Local nil → prefer incoming
        guard let i = incomingAt else { return true } // Incoming nil → prefer local
        return l > i  // Both have timestamps → prefer newer
    }

    private func persistThemeRaw(_ themeRaw: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(themeRaw, forKey: themeKey)
    }

}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let isReachable = session.isReachable
        let shouldSync = activationState == .activated

        Task { @MainActor in
            self.isReachable = isReachable
            if shouldSync {
                self.requestSync()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable

        Task { @MainActor in
            self.isReachable = isReachable
            if isReachable {
                self.requestSync()
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if let themeRaw = message[WatchMessageKey.selectedTheme] as? String {
            Task { @MainActor in
                self.persistThemeRaw(themeRaw)
            }
        }

        if let data = message[WatchMessageKey.workoutData] as? Data,
           let workout = decodeWatchWorkoutData(from: data) {
            Task { @MainActor in
                self.updateWorkoutData(workout)
            }
        }

        // Handle set uncomplete message from phone
        if let setIdString = message[WatchMessageKey.setUncomplete] as? String,
           let setId = UUID(uuidString: setIdString) {
            Task { @MainActor in
                self.markSetUncompleted(setId: setId)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let themeRaw = message[WatchMessageKey.selectedTheme] as? String {
            Task { @MainActor in
                self.persistThemeRaw(themeRaw)
            }
        }

        if let data = message[WatchMessageKey.workoutData] as? Data,
           let workout = decodeWatchWorkoutData(from: data) {
            Task { @MainActor in
                self.updateWorkoutData(workout)
            }
        }
        replyHandler([:])
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if let themeRaw = applicationContext[WatchMessageKey.selectedTheme] as? String {
            Task { @MainActor in
                self.persistThemeRaw(themeRaw)
            }
        }

        if let data = applicationContext[WatchMessageKey.workoutData] as? Data,
           let workout = decodeWatchWorkoutData(from: data) {
            Task { @MainActor in
                self.updateWorkoutData(workout)
            }
        }
    }
}
