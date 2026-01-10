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
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [WatchMessageKey.requestSync: true]
        session.sendMessage(message, replyHandler: nil) { @Sendable error in
            Task { @MainActor in
                print("Error requesting sync: \(error.localizedDescription)")
            }
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

        for i in data.exercises.indices {
            for j in data.exercises[i].sets.indices {
                if data.exercises[i].sets[j].id == setId {
                    data.exercises[i].sets[j].isCompleted = true
                    workoutData = data
                    return
                }
            }
        }
    }

    /// Marks a set as not completed locally (for immediate UI update when phone reverts a set).
    func markSetUncompleted(setId: UUID) {
        guard var data = workoutData else { return }

        for i in data.exercises.indices {
            for j in data.exercises[i].sets.indices {
                if data.exercises[i].sets[j].id == setId {
                    data.exercises[i].sets[j].isCompleted = false
                    workoutData = data
                    return
                }
            }
        }
    }

    // MARK: - Private Methods

    private func updateWorkoutData(_ workout: WatchWorkoutData) {
        self.workoutData = workout
        self.lastSyncDate = Date()
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
        if let data = applicationContext[WatchMessageKey.workoutData] as? Data,
           let workout = decodeWatchWorkoutData(from: data) {
            Task { @MainActor in
                self.updateWorkoutData(workout)
            }
        }
    }
}
