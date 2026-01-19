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
    nonisolated(unsafe) static let selectedTheme = "selectedTheme"
}

// MARK: - Watch Data Models (shared with Watch app)

struct PhoneWatchWorkoutData: Sendable {
    let isRoutineMode: Bool
    /// Ungrouped exercises (orderIndex is used for ordering).
    let exercises: [PhoneWatchExerciseData]
    /// Grouped exercises (supersets/giant sets).
    let exerciseGroups: [PhoneWatchExerciseGroupData]
    let defaultRestTimeSeconds: Int
    /// Whether to automatically start rest timer after recording (combination mode).
    let combineRecordAndTimerStart: Bool
    /// Whether to skip rest timer on the final set of each exercise.
    let skipRestTimerOnFinalSet: Bool

    nonisolated init(
        isRoutineMode: Bool,
        exercises: [PhoneWatchExerciseData],
        exerciseGroups: [PhoneWatchExerciseGroupData] = [],
        defaultRestTimeSeconds: Int,
        combineRecordAndTimerStart: Bool,
        skipRestTimerOnFinalSet: Bool = true
    ) {
        self.isRoutineMode = isRoutineMode
        self.exercises = exercises
        self.exerciseGroups = exerciseGroups
        self.defaultRestTimeSeconds = defaultRestTimeSeconds
        self.combineRecordAndTimerStart = combineRecordAndTimerStart
        self.skipRestTimerOnFinalSet = skipRestTimerOnFinalSet
    }
}

extension PhoneWatchWorkoutData: Codable {
    enum CodingKeys: String, CodingKey {
        case isRoutineMode, exercises, exerciseGroups, defaultRestTimeSeconds, combineRecordAndTimerStart, skipRestTimerOnFinalSet
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isRoutineMode = try container.decode(Bool.self, forKey: .isRoutineMode)
        exercises = try container.decode([PhoneWatchExerciseData].self, forKey: .exercises)
        exerciseGroups = try container.decodeIfPresent([PhoneWatchExerciseGroupData].self, forKey: .exerciseGroups) ?? []
        defaultRestTimeSeconds = try container.decode(Int.self, forKey: .defaultRestTimeSeconds)
        combineRecordAndTimerStart = try container.decodeIfPresent(Bool.self, forKey: .combineRecordAndTimerStart) ?? false
        skipRestTimerOnFinalSet = try container.decodeIfPresent(Bool.self, forKey: .skipRestTimerOnFinalSet) ?? true
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isRoutineMode, forKey: .isRoutineMode)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(exerciseGroups, forKey: .exerciseGroups)
        try container.encode(defaultRestTimeSeconds, forKey: .defaultRestTimeSeconds)
        try container.encode(combineRecordAndTimerStart, forKey: .combineRecordAndTimerStart)
        try container.encode(skipRestTimerOnFinalSet, forKey: .skipRestTimerOnFinalSet)
    }
}

struct PhoneWatchExerciseGroupData: Identifiable, Sendable {
    let id: UUID
    let orderIndex: Int
    let setCount: Int
    let roundRestSeconds: Int?
    let exercises: [PhoneWatchExerciseData]

    nonisolated init(
        id: UUID,
        orderIndex: Int,
        setCount: Int,
        roundRestSeconds: Int?,
        exercises: [PhoneWatchExerciseData]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.setCount = setCount
        self.roundRestSeconds = roundRestSeconds
        self.exercises = exercises
    }
}

extension PhoneWatchExerciseGroupData: Codable {
    enum CodingKeys: String, CodingKey {
        case id, orderIndex, setCount, roundRestSeconds, exercises
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        setCount = try container.decode(Int.self, forKey: .setCount)
        roundRestSeconds = try container.decodeIfPresent(Int.self, forKey: .roundRestSeconds)
        exercises = try container.decode([PhoneWatchExerciseData].self, forKey: .exercises)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encode(setCount, forKey: .setCount)
        try container.encodeIfPresent(roundRestSeconds, forKey: .roundRestSeconds)
        try container.encode(exercises, forKey: .exercises)
    }
}

struct PhoneWatchExerciseData: Identifiable, Sendable {
    let id: UUID
    let exerciseId: UUID
    let name: String
    let orderIndex: Int
    /// Display order within a group (0-indexed). nil means ungrouped.
    let groupOrderIndex: Int?
    let metricType: String
    let bodyPartCode: String?
    let sets: [PhoneWatchSetData]

    nonisolated init(
        id: UUID,
        exerciseId: UUID,
        name: String,
        orderIndex: Int,
        groupOrderIndex: Int? = nil,
        metricType: String,
        bodyPartCode: String?,
        sets: [PhoneWatchSetData]
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.name = name
        self.orderIndex = orderIndex
        self.groupOrderIndex = groupOrderIndex
        self.metricType = metricType
        self.bodyPartCode = bodyPartCode
        self.sets = sets
    }
}

extension PhoneWatchExerciseData: Codable {
    enum CodingKeys: String, CodingKey {
        case id, exerciseId, name, orderIndex, groupOrderIndex, metricType, bodyPartCode, sets
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        name = try container.decode(String.self, forKey: .name)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        groupOrderIndex = try container.decodeIfPresent(Int.self, forKey: .groupOrderIndex)
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
        try container.encodeIfPresent(groupOrderIndex, forKey: .groupOrderIndex)
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
    var completedAt: Date?

    nonisolated init(
        id: UUID,
        setIndex: Int,
        weight: Double?,
        reps: Int?,
        durationSeconds: Int?,
        distanceMeters: Double?,
        restTimeSeconds: Int?,
        isCompleted: Bool,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restTimeSeconds = restTimeSeconds
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

extension PhoneWatchSetData: Codable {
    enum CodingKeys: String, CodingKey {
        case id, setIndex, weight, reps, durationSeconds, distanceMeters, restTimeSeconds, isCompleted, completedAt
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
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
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
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
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
        combineRecordAndTimerStart: Bool = false,
        skipRestTimerOnFinalSet: Bool = true
    ) {
        guard let session = session else { return }

        let watchData = buildWatchWorkoutData(
            workoutDay: workoutDay,
            exercises: exercises,
            bodyParts: bodyParts,
            defaultRestTimeSeconds: defaultRestTimeSeconds,
            combineRecordAndTimerStart: combineRecordAndTimerStart,
            skipRestTimerOnFinalSet: skipRestTimerOnFinalSet
        )

        do {
            let data = try JSONEncoder().encode(watchData)
            // Include selected theme so Watch can persist it locally.
            let themeRaw = ThemeManager.shared.currentThemeType.rawValue
            let message: [String: Any] = [
                PhoneWatchMessageKey.workoutData: data,
                PhoneWatchMessageKey.selectedTheme: themeRaw,
            ]

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
        combineRecordAndTimerStart: Bool,
        skipRestTimerOnFinalSet: Bool
    ) -> PhoneWatchWorkoutData {
        // Send workout content to Watch for both routine and non-routine days.
        // The Watch UI will decide how to present it (e.g., show "no workout" only when empty).
        guard let workoutDay = workoutDay else {
            return PhoneWatchWorkoutData(
                isRoutineMode: false,
                exercises: [],
                exerciseGroups: [],
                defaultRestTimeSeconds: defaultRestTimeSeconds,
                combineRecordAndTimerStart: combineRecordAndTimerStart,
                skipRestTimerOnFinalSet: skipRestTimerOnFinalSet
            )
        }

        let isRoutineMode = workoutDay.mode == .routine

        // Create a dictionary for quick body part lookup
        let bodyPartDict = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })

        func makeExerciseData(entry: WorkoutExerciseEntry, groupOrderIndex: Int? = nil) -> PhoneWatchExerciseData {
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
                    isCompleted: set.isCompleted,
                    completedAt: set.completedAt
                )
            }

            return PhoneWatchExerciseData(
                id: entry.id,
                exerciseId: entry.exerciseId,
                name: exerciseName,
                orderIndex: entry.orderIndex,
                groupOrderIndex: groupOrderIndex,
                metricType: entry.metricType.rawValue,
                bodyPartCode: bodyPartCode,
                sets: watchSets
            )
        }

        // Ungrouped entries only (avoid duplicates with exerciseGroups)
        let watchExercises = workoutDay.sortedEntries
            .filter { $0.group == nil }
            .map { entry in
                makeExerciseData(entry: entry)
            }

        let watchGroups = workoutDay.exerciseGroups
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { group -> PhoneWatchExerciseGroupData in
                let groupExercises = group.sortedEntries.map { entry in
                    makeExerciseData(entry: entry, groupOrderIndex: entry.groupOrderIndex)
                }
                return PhoneWatchExerciseGroupData(
                    id: group.id,
                    orderIndex: group.orderIndex,
                    setCount: group.setCount,
                    roundRestSeconds: group.roundRestSeconds,
                    exercises: groupExercises
                )
            }

        return PhoneWatchWorkoutData(
            isRoutineMode: isRoutineMode,
            exercises: watchExercises,
            exerciseGroups: watchGroups,
            defaultRestTimeSeconds: defaultRestTimeSeconds,
            combineRecordAndTimerStart: combineRecordAndTimerStart,
            skipRestTimerOnFinalSet: skipRestTimerOnFinalSet
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
        if userInfo[PhoneWatchMessageKey.requestSync] != nil {
            Task { @MainActor in
                self.handleSyncRequest()
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let watchRequestedSync = Notification.Name("watchRequestedSync")
}
