//
//  Strings.swift
//  Routyra
//
//  Centralized string constants for localization.
//  Currently Japanese only. Can be extended for multi-language support.
//

import Foundation

enum Strings {
    // MARK: - Common
    static let cancel = "キャンセル"
    static let delete = "削除"
    static let create = "作成"
    static let done = "完了"
    static let edit = "編集"
    static let save = "保存"
    static let none = "なし"
    static let active = "アクティブ"
    static let notSet = "未設定"

    // MARK: - Workout Plans Screen
    static let workoutPlans = "ワークアウトプラン"
    static let executionMode = "実行方法"
    static let singlePlan = "単体プラン"
    static let cycle = "サイクル"
    static let activePlan = "有効なプラン"
    static let selectActivePlan = "有効なプランを選択"
    static let noActiveCycle = "アクティブなサイクルがありません"
    static let noPlansInCycle = "プランがありません"
    static let editCycles = "サイクルを編集"
    static let plansList = "プラン一覧"
    static let addPlan = "プランを追加"
    static let addPlanSubtitle = "新しいワークアウトプランを作成"
    static let noPlans = "プランがありません"
    static let createPlanHint = "上のカードからプランを作成しましょう"
    static let newPlan = "新しいプラン"
    static let planName = "プラン名"
    static let enterPlanName = "プラン名を入力してください"

    // MARK: - Plan Card
    static let daysUnit = "日"
    static let exercisesUnit = "種目"

    // MARK: - Delete Plan
    static let deletePlan = "プランを削除"
    static func deletePlanConfirm(_ name: String) -> String {
        "「\(name)」を削除しますか？この操作は取り消せません。"
    }
    static let deleteActivePlan = "有効なプランを削除"
    static let deleteActivePlanWarning = "このプランは現在有効に設定されています。削除すると有効なプランがなくなります。"

    // MARK: - Cycle
    static let newCycle = "新しいサイクル"
    static let cycleName = "サイクル名"
    static let enterCycleName = "サイクル名を入力してください"
    static let noCycles = "サイクルがありません"
    static let cycleDescription = "複数のプランを順番に回すサイクルを作成できます"
    static let cycleList = "サイクル一覧"
    static let plansCount = "プラン"
    static let deactivate = "アクティブを解除"
    static let activate = "アクティブに設定"

    // MARK: - Days
    static let days = "Days"
    static let addDay = "Dayを追加"
    static let reorder = "並び替え"
    static let duplicateDay = "Dayを複製"
    static let deleteDay = "Dayを削除"
    static let renameDay = "名前を変更"

    // MARK: - Plan Editor
    static let planInfo = "プラン情報"
    static let setPlanName = "プラン名を設定"
    static let noMemo = "メモなし"
    static let memo = "メモ"
    static let memoOptional = "メモ（任意）"
    static let discardChanges = "変更を破棄"
    static let discardChangesMessage = "保存されていない変更があります。破棄しますか？"
    static let discard = "破棄"
    static let continueEditing = "編集を続ける"
    static let editPlan = "プランを編集"

    // MARK: - Exercises
    static let addExercise = "種目を追加"
    static let noExercises = "種目がありません"
    static let unknownExercise = "不明な種目"
    static let noSetsConfigured = "セットが設定されていません"

    // MARK: - Sets
    static let set = "セット"
    static let sets = "セット"
    static let reps = "回"
    static let kg = "kg"
}
