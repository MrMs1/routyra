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
        "treadmill": .running,
        "cycling": .cycling,
        "rowing": .rowing,
        "elliptical": .elliptical,
        "jump_rope": .jumpRope,
        "stair_climber": .stairClimbing
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
