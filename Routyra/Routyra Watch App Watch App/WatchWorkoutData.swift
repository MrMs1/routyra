//
//  WatchWorkoutData.swift
//  Routyra Watch App Watch App
//
//  Simplified data models for Watch app.
//  These are Codable structs transferred via Watch Connectivity.
//

import Foundation

// MARK: - Watch Workout Data

/// Complete workout data transferred from iPhone to Watch.
struct WatchWorkoutData: Sendable {
    let isRoutineMode: Bool
    var exercises: [WatchExerciseData]
    let defaultRestTimeSeconds: Int
    /// Whether to automatically start rest timer after recording (combination mode).
    let combineRecordAndTimerStart: Bool

    nonisolated init(isRoutineMode: Bool, exercises: [WatchExerciseData], defaultRestTimeSeconds: Int, combineRecordAndTimerStart: Bool) {
        self.isRoutineMode = isRoutineMode
        self.exercises = exercises
        self.defaultRestTimeSeconds = defaultRestTimeSeconds
        self.combineRecordAndTimerStart = combineRecordAndTimerStart
    }
}

extension WatchWorkoutData: Codable {
    enum CodingKeys: String, CodingKey {
        case isRoutineMode, exercises, defaultRestTimeSeconds, combineRecordAndTimerStart
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isRoutineMode = try container.decode(Bool.self, forKey: .isRoutineMode)
        exercises = try container.decode([WatchExerciseData].self, forKey: .exercises)
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

// MARK: - Watch Exercise Data

/// Exercise data for Watch display.
struct WatchExerciseData: Identifiable, Sendable {
    let id: UUID
    let exerciseId: UUID
    let name: String
    let orderIndex: Int
    let metricType: String  // "weightReps", "bodyweightReps", "timeDistance", "completion"
    let bodyPartCode: String?  // Body part code for color dot
    var sets: [WatchSetData]

    nonisolated init(id: UUID, exerciseId: UUID, name: String, orderIndex: Int, metricType: String, bodyPartCode: String?, sets: [WatchSetData]) {
        self.id = id
        self.exerciseId = exerciseId
        self.name = name
        self.orderIndex = orderIndex
        self.metricType = metricType
        self.bodyPartCode = bodyPartCode
        self.sets = sets
    }
}

extension WatchExerciseData: Codable {
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
        sets = try container.decode([WatchSetData].self, forKey: .sets)
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

// MARK: - Watch Set Data

/// Set data for Watch display and recording.
struct WatchSetData: Identifiable, Sendable {
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

extension WatchSetData: Codable {
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

// MARK: - Watch Metric Type

enum WatchMetricType: String, Codable, Sendable {
    case weightReps
    case bodyweightReps
    case timeDistance
    case completion
}

// MARK: - Set Completion Message

/// Message sent from Watch to iPhone when a set is completed.
struct WatchSetCompletionMessage: Sendable {
    let setId: UUID
    let completedAt: Date

    nonisolated init(setId: UUID, completedAt: Date) {
        self.setId = setId
        self.completedAt = completedAt
    }
}

extension WatchSetCompletionMessage: Codable {
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

// MARK: - Watch Connectivity Message Keys

enum WatchMessageKey: Sendable {
    nonisolated(unsafe) static let workoutData = "workoutData"
    nonisolated(unsafe) static let setCompletion = "setCompletion"
    nonisolated(unsafe) static let setUncomplete = "setUncomplete"
    nonisolated(unsafe) static let requestSync = "requestSync"
}

// MARK: - Decoder Helper

/// Decodes WatchWorkoutData from Data (nonisolated helper for WCSessionDelegate)
nonisolated func decodeWatchWorkoutData(from data: Data) -> WatchWorkoutData? {
    try? JSONDecoder().decode(WatchWorkoutData.self, from: data)
}
