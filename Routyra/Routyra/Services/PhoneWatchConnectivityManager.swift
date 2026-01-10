//
//  PhoneWatchConnectivityManager.swift
//  Routyra
//
//  Manages Watch Connectivity session for sending workout data to Watch
//  and receiving set completions.
//

import Combine
import Foundation
import SwiftData
import WatchConnectivity

// MARK: - Watch Message Keys (shared with Watch app)

enum PhoneWatchMessageKey: Sendable {
    nonisolated(unsafe) static let workoutData = "workoutData"
    nonisolated(unsafe) static let setCompletion = "setCompletion"
    nonisolated(unsafe) static let setUncomplete = "setUncomplete"
    nonisolated(unsafe) static let requestSync = "requestSync"
}

// MARK: - Watch Data Models (shared with Watch app)

struct PhoneWatchWorkoutData: Sendable {
    let isRoutineMode: Bool
    let exercises: [PhoneWatchExerciseData]
    let defaultRestTimeSeconds: Int
    /// Whether to automatically start rest timer after recording (combination mode).
    let combineRecordAndTimerStart: Bool

    nonisolated init(isRoutineMode: Bool, exercises: [PhoneWatchExerciseData], defaultRestTimeSeconds: Int, combineRecordAndTimerStart: Bool) {
        self.isRoutineMode = isRoutineMode
        self.exercises = exercises
        self.defaultRestTimeSeconds = defaultRestTimeSeconds
        self.combineRecordAndTimerStart = combineRecordAndTimerStart
    }
}

extension PhoneWatchWorkoutData: Codable {
    enum CodingKeys: String, CodingKey {
        case isRoutineMode, exercises, defaultRestTimeSeconds, combineRecordAndTimerStart
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isRoutineMode = try container.decode(Bool.self, forKey: .isRoutineMode)
        exercises = try container.decode([PhoneWatchExerciseData].self, forKey: .exercises)
        defaultRestTimeSeconds = try container.decode(Int.self, forKey: .defaultRestTimeSeconds)
        combineRecordAndTimerStart = try container.decodeIfPresent(Bool.self, forKey: .combineRecordAndTimerStart) ?? false
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isRoutineMode, forKey: .isRoutineMode)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(defaultRestTimeSeconds, forKey: .defaultRestTimeSeconds)
        try container.encode(combineRecordAndTimerStart, forKey: .combineRecordAndTimerStart)
    }
}

struct PhoneWatchExerciseData: Identifiable, Sendable {
    let id: UUID
    let exerciseId: UUID
    let name: String
    let orderIndex: Int
    let metricType: String
    let bodyPartCode: String?
    let sets: [PhoneWatchSetData]

    nonisolated init(id: UUID, exerciseId: UUID, name: String, orderIndex: Int, metricType: String, bodyPartCode: String?, sets: [PhoneWatchSetData]) {
        self.id = id
        self.exerciseId = exerciseId
        self.name = name
        self.orderIndex = orderIndex
        self.metricType = metricType
        self.bodyPartCode = bodyPartCode
        self.sets = sets
    }
}

extension PhoneWatchExerciseData: Codable {
    enum CodingKeys: String, CodingKey {
        case id, exerciseId, name, orderIndex, metricType, bodyPartCode, sets
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        name = try container.decode(String.self, forKey: .name)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        metricType = try container.decode(String.self, forKey: .metricType)
        bodyPartCode = try container.decodeIfPresent(String.self, forKey: .bodyPartCode)
        sets = try container.decode([PhoneWatchSetData].self, forKey: .sets)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(exerciseId, forKey: .exerciseId)
        try container.encode(name, forKey: .name)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encode(metricType, forKey: .metricType)
        try container.encodeIfPresent(bodyPartCode, forKey: .bodyPartCode)
        try container.encode(sets, forKey: .sets)
    }
}

struct PhoneWatchSetData: Identifiable, Sendable {
    let id: UUID
    let setIndex: Int
    let weight: Double?
    let reps: Int?
    let durationSeconds: Int?
    let distanceMeters: Double?
    let restTimeSeconds: Int?
    var isCompleted: Bool

    nonisolated init(
        id: UUID,
        setIndex: Int,
        weight: Double?,
        reps: Int?,
        durationSeconds: Int?,
        distanceMeters: Double?,
        restTimeSeconds: Int?,
        isCompleted: Bool
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restTimeSeconds = restTimeSeconds
        self.isCompleted = isCompleted
    }
}

extension PhoneWatchSetData: Codable {
    enum CodingKeys: String, CodingKey {
        case id, setIndex, weight, reps, durationSeconds, distanceMeters, restTimeSeconds, isCompleted
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setIndex = try container.decode(Int.self, forKey: .setIndex)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        restTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .restTimeSeconds)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(setIndex, forKey: .setIndex)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
        try container.encodeIfPresent(restTimeSeconds, forKey: .restTimeSeconds)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}

struct PhoneWatchSetCompletionMessage: Sendable {
    let setId: UUID
    let completedAt: Date

    nonisolated init(setId: UUID, completedAt: Date) {
        self.setId = setId
        self.completedAt = completedAt
    }
}

extension PhoneWatchSetCompletionMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case setId, completedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setId = try container.decode(UUID.self, forKey: .setId)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(setId, forKey: .setId)
        try container.encode(completedAt, forKey: .completedAt)
    }
}

// MARK: - Phone Watch Connectivity Manager

@MainActor
final class PhoneWatchConnectivityManager: NSObject, ObservableObject {
    // MARK: - Singleton

    static let shared = PhoneWatchConnectivityManager()

    // MARK: - Published State

    @Published private(set) var isWatchAppInstalled: Bool = false
    @Published private(set) var isReachable: Bool = false

    // MARK: - Callbacks

    var onSetCompleted: ((UUID) -> Void)?

    // MARK: - Private Properties

    private var session: WCSession?
    private var modelContext: ModelContext?

    // MARK: - Initialization

    private override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Sends current workout data to Watch.
    func sendWorkoutData(
        workoutDay: WorkoutDay?,
        exercises: [Exercise],
        bodyParts: [BodyPart] = [],
        defaultRestTimeSeconds: Int,
        combineRecordAndTimerStart: Bool = false
    ) {
        guard let session = session else { return }

        let watchData = buildWatchWorkoutData(
            workoutDay: workoutDay,
            exercises: exercises,
            bodyParts: bodyParts,
            defaultRestTimeSeconds: defaultRestTimeSeconds,
            combineRecordAndTimerStart: combineRecordAndTimerStart
        )

        do {
            let data = try JSONEncoder().encode(watchData)
            let message: [String: Any] = [PhoneWatchMessageKey.workoutData: data]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { @Sendable error in
                    Task { @MainActor in
                        print("Error sending workout data: \(error.localizedDescription)")
                    }
                }
            } else {
                // Update application context for background delivery
                try session.updateApplicationContext(message)
            }
        } catch {
            print("Error encoding workout data: \(error.localizedDescription)")
        }
    }

    /// Sends set uncomplete message to Watch.
    func sendSetUncomplete(setId: UUID) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            PhoneWatchMessageKey.setUncomplete: setId.uuidString
        ]

        session.sendMessage(message, replyHandler: nil) { @Sendable error in
            Task { @MainActor in
                print("Error sending set uncomplete: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func buildWatchWorkoutData(
        workoutDay: WorkoutDay?,
        exercises: [Exercise],
        bodyParts: [BodyPart],
        defaultRestTimeSeconds: Int,
        combineRecordAndTimerStart: Bool
    ) -> PhoneWatchWorkoutData {
        guard let workoutDay = workoutDay, workoutDay.mode == .routine else {
            return PhoneWatchWorkoutData(
                isRoutineMode: false,
                exercises: [],
                defaultRestTimeSeconds: defaultRestTimeSeconds,
                combineRecordAndTimerStart: combineRecordAndTimerStart
            )
        }

        // Create a dictionary for quick body part lookup
        let bodyPartDict = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })

        let watchExercises = workoutDay.sortedEntries.map { entry -> PhoneWatchExerciseData in
            let exercise = exercises.first { $0.id == entry.exerciseId }
            let exerciseName = exercise?.localizedName ?? "Unknown"

            // Look up body part code
            let bodyPartCode: String? = exercise?.bodyPartId.flatMap { bodyPartDict[$0]?.code }

            let watchSets = entry.sortedSets.map { set -> PhoneWatchSetData in
                // Convert Decimal weight to Double
                let weightDouble: Double? = set.weight.map { NSDecimalNumber(decimal: $0).doubleValue }

                return PhoneWatchSetData(
                    id: set.id,
                    setIndex: set.setIndex,
                    weight: weightDouble,
                    reps: set.reps,
                    durationSeconds: set.durationSeconds,
                    distanceMeters: set.distanceMeters,
                    restTimeSeconds: set.restTimeSeconds,
                    isCompleted: set.isCompleted
                )
            }

            return PhoneWatchExerciseData(
                id: entry.id,
                exerciseId: entry.exerciseId,
                name: exerciseName,
                orderIndex: entry.orderIndex,
                metricType: entry.metricType.rawValue,
                bodyPartCode: bodyPartCode,
                sets: watchSets
            )
        }

        return PhoneWatchWorkoutData(
            isRoutineMode: true,
            exercises: watchExercises,
            defaultRestTimeSeconds: defaultRestTimeSeconds,
            combineRecordAndTimerStart: combineRecordAndTimerStart
        )
    }

    private func handleSetCompletion(_ data: Data) {
        do {
            let completion = try JSONDecoder().decode(PhoneWatchSetCompletionMessage.self, from: data)
            self.onSetCompleted?(completion.setId)
        } catch {
            print("Error decoding set completion: \(error.localizedDescription)")
        }
    }

    private func handleSyncRequest() {
        // This will be called when Watch requests a sync
        // The caller should observe this and send updated data
        NotificationCenter.default.post(name: .watchRequestedSync, object: nil)
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let isWatchAppInstalled = session.isWatchAppInstalled
        let isReachable = session.isReachable

        Task { @MainActor in
            self.isWatchAppInstalled = isWatchAppInstalled
            self.isReachable = isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let isWatchAppInstalled = session.isWatchAppInstalled

        Task { @MainActor in
            self.isWatchAppInstalled = isWatchAppInstalled
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable

        Task { @MainActor in
            self.isReachable = isReachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if let data = message[PhoneWatchMessageKey.setCompletion] as? Data {
            Task { @MainActor in
                self.handleSetCompletion(data)
            }
        }
        if message[PhoneWatchMessageKey.requestSync] != nil {
            Task { @MainActor in
                self.handleSyncRequest()
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let data = message[PhoneWatchMessageKey.setCompletion] as? Data {
            Task { @MainActor in
                self.handleSetCompletion(data)
            }
        }
        if message[PhoneWatchMessageKey.requestSync] != nil {
            Task { @MainActor in
                self.handleSyncRequest()
            }
        }
        replyHandler([:])
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        if let data = userInfo[PhoneWatchMessageKey.setCompletion] as? Data {
            Task { @MainActor in
                self.handleSetCompletion(data)
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let watchRequestedSync = Notification.Name("watchRequestedSync")
}
