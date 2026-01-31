//
//  PlanDayDisplayService.swift
//  Routyra
//
//  Provides unified display items for plan day exercises and groups.
//

import Foundation

/// グループとエクササイズを統一的に扱うための表示アイテム
enum PlanDayDisplayItem: Identifiable {
    case group(PlanExerciseGroup)
    case exercise(PlanExercise)

    var id: String {
        switch self {
        case .group(let group): return "group-\(group.id)"
        case .exercise(let exercise): return "exercise-\(exercise.id)"
        }
    }

    var orderIndex: Int {
        switch self {
        case .group(let group): return group.orderIndex
        case .exercise(let exercise): return exercise.orderIndex
        }
    }

    /// タイブレーク用のID（orderIndex同値時の安定ソート）
    var sortId: UUID {
        switch self {
        case .group(let group): return group.id
        case .exercise(let exercise): return exercise.id
        }
    }
}

/// PlanDayから表示アイテムを構築するサービス
enum PlanDayDisplayService {
    /// グループと非グループエクササイズを統合してソート
    static func buildDisplayItems(from planDay: PlanDay) -> [PlanDayDisplayItem] {
        var items: [PlanDayDisplayItem] = []

        for group in planDay.exerciseGroups {
            items.append(.group(group))
        }

        for exercise in planDay.sortedExercises where !exercise.isGrouped {
            items.append(.exercise(exercise))
        }

        // タイブレーク付きソート（orderIndex同値時はUUIDで安定ソート）
        return items.sorted {
            if $0.orderIndex != $1.orderIndex {
                return $0.orderIndex < $1.orderIndex
            }
            return $0.sortId.uuidString < $1.sortId.uuidString
        }
    }
}
