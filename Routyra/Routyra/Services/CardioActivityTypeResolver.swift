//
//  CardioActivityTypeResolver.swift
//  Routyra
//
//  Resolves cardio activity types for plan/workout conversion.
//

import Foundation
import HealthKit

enum CardioActivityTypeResolver {
    private static let codeToActivityType: [String: HKWorkoutActivityType] = [
        // Backward-compatibility:
        // These codes may exist in older local databases, but we no longer seed them
        // because HealthKit represents running as a single activity type.
        "indoor_running": .running,
        "outdoor_running": .running,

        "treadmill": .running,
        "cycling": .cycling,
        "rowing": .rowing,
        "elliptical": .elliptical,
        "jump_rope": .jumpRope,
        "stair_climber": .stairClimbing,
        "stepper": .stepTraining,
        "hiit": .highIntensityIntervalTraining
    ]

    static func isCardioExercise(_ exercise: Exercise, bodyPartsMap: [UUID: BodyPart]) -> Bool {
        guard let bodyPartId = exercise.bodyPartId else { return false }
        return bodyPartsMap[bodyPartId]?.code == "cardio"
    }

    static func activityType(for exercise: Exercise) -> HKWorkoutActivityType {
        guard let code = exercise.code,
              let type = codeToActivityType[code] else {
            return .mixedCardio
        }
        return type
    }
}
