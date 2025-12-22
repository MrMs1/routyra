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
    static let cancel = L10n.tr("cancel")
    static let delete = L10n.tr("delete")
    static let create = L10n.tr("create")
    static let done = L10n.tr("done")
    static let edit = L10n.tr("edit")
    static let save = L10n.tr("save")
    static let none = L10n.tr("none")
    static let active = L10n.tr("active")
    static let notSet = L10n.tr("not_set")

    // MARK: - Workout Plans Screen
    static let workoutPlans = L10n.tr("workout_plans")
    static let executionMode = L10n.tr("execution_mode")
    static let singlePlan = L10n.tr("single_plan")
    static let cycle = L10n.tr("cycle")
    static let activePlan = L10n.tr("active_plan")
    static let selectActivePlan = L10n.tr("select_active_plan")
    static let noActiveCycle = L10n.tr("no_active_cycle")
    static let noPlansInCycle = L10n.tr("no_plans_in_cycle")
    static let editCycles = L10n.tr("edit_cycles")
    static let plansList = L10n.tr("plans")
    static let addPlan = L10n.tr("add_plan")
    static let addPlanSubtitle = L10n.tr("add_plan_subtitle")
    static let noPlans = L10n.tr("no_plans")
    static let createPlanHint = L10n.tr("create_plan_hint")
    static let newPlan = L10n.tr("new_plan")
    static let planName = L10n.tr("plan_name")
    static let enterPlanName = L10n.tr("enter_plan_name")

    // MARK: - Plan Card
    static let daysUnit = L10n.tr("days_unit")
    static let exercisesUnit = L10n.tr("exercises_unit")

    // MARK: - Delete Plan
    static let deletePlan = L10n.tr("delete_plan")
    static func deletePlanConfirm(_ name: String) -> String {
        L10n.tr("delete_plan_confirm", name)
    }
    static let deleteActivePlan = L10n.tr("delete_active_plan")
    static let deleteActivePlanWarning = L10n.tr("delete_active_plan_warning")

    // MARK: - Cycle
    static let newCycle = L10n.tr("cycle_new_title")
    static let cycleName = L10n.tr("cycle_name_placeholder")
    static let enterCycleName = L10n.tr("cycle_name_required")
    static let noCycles = L10n.tr("cycle_empty_title")
    static let cycleDescription = L10n.tr("cycle_empty_description")
    static let cycleList = L10n.tr("cycle_list_title")
    static let plansCount = L10n.tr("plans_count")
    static let deactivate = L10n.tr("deactivate")
    static let activate = L10n.tr("activate")

    // MARK: - Days
    static let days = L10n.tr("days")
    static let addDay = L10n.tr("add_day")
    static let reorder = L10n.tr("reorder")
    static let duplicateDay = L10n.tr("duplicate_day")
    static let deleteDay = L10n.tr("delete_day")
    static let renameDay = L10n.tr("rename_day")

    // MARK: - Plan Editor
    static let planInfo = L10n.tr("plan_info")
    static let setPlanName = L10n.tr("plan_set_name")
    static let noMemo = L10n.tr("no_memo")
    static let memo = L10n.tr("memo")
    static let memoOptional = L10n.tr("memo_optional")
    static let discardChanges = L10n.tr("discard_changes")
    static let discardChangesMessage = L10n.tr("discard_changes_message")
    static let discard = L10n.tr("discard")
    static let continueEditing = L10n.tr("continue_editing")
    static let editPlan = L10n.tr("edit_plan")

    // MARK: - Exercises
    static let addExercise = L10n.tr("add_exercise")
    static let noExercises = L10n.tr("no_exercises")
    static let unknownExercise = L10n.tr("unknown_exercise")
    static let noSetsConfigured = L10n.tr("no_sets_configured")

    // MARK: - Sets
    static let set = L10n.tr("set")
    static let sets = L10n.tr("sets")
    static let reps = L10n.tr("unit_reps")
    static let kg = L10n.tr("unit_kg")
}
