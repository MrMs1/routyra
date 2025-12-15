//
//  ExerciseCreationService.swift
//  Routyra
//
//  Service for creating user exercises with validation.
//

import Foundation
import SwiftData

// MARK: - Domain Errors

/// Errors that can occur during exercise creation.
enum ExerciseCreationError: LocalizedError {
    /// The exercise name is empty or contains only whitespace.
    case emptyName
    /// An exercise with the same name already exists in this body part.
    case duplicateExercise(existingId: UUID, existingName: String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "エクササイズ名を入力してください"
        case .duplicateExercise(_, let name):
            return "「\(name)」は既に登録されています"
        }
    }
}

// MARK: - ExerciseCreationService

/// Service for creating and managing user exercises.
enum ExerciseCreationService {
    // MARK: - Exercise Creation

    /// Creates a new user exercise under the specified body part.
    /// - Parameters:
    ///   - profile: The local profile (owner).
    ///   - bodyPart: The body part this exercise belongs to.
    ///   - name: The display name of the exercise.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The created exercise.
    /// - Throws: `ExerciseCreationError` if validation fails.
    @MainActor
    static func createUserExercise(
        profile: LocalProfile,
        bodyPart: BodyPart,
        name: String,
        modelContext: ModelContext
    ) throws -> Exercise {
        // Trim whitespace
        let trimmedName = name.trimmed

        // Validate non-empty
        guard !trimmedName.isEmpty else {
            throw ExerciseCreationError.emptyName
        }

        // Check for duplicates
        let normalizedName = trimmedName.normalizedForComparison()
        if let existingExercise = findDuplicateExercise(
            profileId: profile.id,
            bodyPartId: bodyPart.id,
            normalizedName: normalizedName,
            modelContext: modelContext
        ) {
            throw ExerciseCreationError.duplicateExercise(
                existingId: existingExercise.id,
                existingName: existingExercise.name
            )
        }

        // Create the exercise
        let exercise = Exercise.userExercise(
            name: trimmedName,
            profileId: profile.id,
            bodyPartId: bodyPart.id,
            category: bodyPart.name // Also set category for backward compatibility
        )

        modelContext.insert(exercise)
        return exercise
    }

    // MARK: - Duplicate Checking

    /// Finds a duplicate user exercise by normalized name within the same body part.
    @MainActor
    private static func findDuplicateExercise(
        profileId: UUID,
        bodyPartId: UUID,
        normalizedName: String,
        modelContext: ModelContext
    ) -> Exercise? {
        // Fetch all user exercises for this profile and body part
        // Note: SwiftData predicates don't support enum comparison well,
        // so we fetch and filter in memory
        let descriptor = FetchDescriptor<Exercise>()

        do {
            let exercises = try modelContext.fetch(descriptor)
            return exercises.first { exercise in
                exercise.scope == .user &&
                exercise.ownerProfileId == profileId &&
                exercise.bodyPartId == bodyPartId &&
                exercise.normalizedName == normalizedName &&
                !exercise.isArchived
            }
        } catch {
            print("Error checking for duplicate exercise: \(error)")
            return nil
        }
    }

    // MARK: - Fetch Helpers

    /// Fetches all available body parts for a profile.
    /// Returns global body parts plus user-created body parts for this profile.
    /// Sorted by sortOrder, then by name.
    @MainActor
    static func fetchBodyParts(
        for profile: LocalProfile,
        modelContext: ModelContext
    ) -> [BodyPart] {
        let descriptor = FetchDescriptor<BodyPart>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.name)
            ]
        )

        do {
            let allBodyParts = try modelContext.fetch(descriptor)
            return allBodyParts.filter { bodyPart in
                !bodyPart.isArchived &&
                (bodyPart.scope == .global || bodyPart.ownerProfileId == profile.id)
            }
        } catch {
            print("Error fetching body parts: \(error)")
            return []
        }
    }

    /// Fetches all exercises for a specific body part.
    /// Returns global exercises plus user exercises for this profile.
    /// Sorted by name.
    @MainActor
    static func fetchExercises(
        for bodyPart: BodyPart,
        profile: LocalProfile,
        modelContext: ModelContext
    ) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            let allExercises = try modelContext.fetch(descriptor)
            return allExercises.filter { exercise in
                !exercise.isArchived &&
                exercise.bodyPartId == bodyPart.id &&
                (exercise.scope == .global || exercise.ownerProfileId == profile.id)
            }
        } catch {
            print("Error fetching exercises: \(error)")
            return []
        }
    }

    // MARK: - Body Part Seeding

    /// Seeds the database with system body parts if none exist.
    @MainActor
    static func seedSystemBodyPartsIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BodyPart>()

        do {
            let existingBodyParts = try modelContext.fetch(descriptor)
            let hasSystemBodyParts = existingBodyParts.contains { $0.isSystem }

            if !hasSystemBodyParts {
                seedSystemBodyParts(modelContext: modelContext)
            }
        } catch {
            print("Error checking body parts: \(error)")
        }
    }

    /// Seeds the database with system body parts with translations.
    @MainActor
    private static func seedSystemBodyParts(modelContext: ModelContext) {
        let bodyPartsData: [(code: String, defaultName: String, sortOrder: Int, ja: String, en: String)] = [
            ("chest", "Chest", 1, "胸", "Chest"),
            ("back", "Back", 2, "背中", "Back"),
            ("shoulders", "Shoulders", 3, "肩", "Shoulders"),
            ("arms", "Arms", 4, "腕", "Arms"),
            ("abs", "Abs", 5, "腹筋", "Abs"),
            ("legs", "Legs", 6, "脚", "Legs"),
            ("glutes", "Glutes", 7, "お尻", "Glutes"),
            ("full_body", "Full Body", 8, "全身", "Full Body"),
            ("cardio", "Cardio", 9, "有酸素", "Cardio"),
        ]

        for data in bodyPartsData {
            let bodyPart = BodyPart.systemBodyPart(
                code: data.code,
                defaultName: data.defaultName,
                sortOrder: data.sortOrder
            )
            bodyPart.addTranslation(locale: "ja", name: data.ja)
            bodyPart.addTranslation(locale: "en", name: data.en)
            modelContext.insert(bodyPart)
        }
    }

    // MARK: - Exercise Seeding

    /// Seeds the database with system exercises if none exist.
    @MainActor
    static func seedSystemExercisesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()

        do {
            let existingExercises = try modelContext.fetch(descriptor)
            let hasSystemExercises = existingExercises.contains { $0.isSystem }

            if !hasSystemExercises {
                seedSystemExercises(modelContext: modelContext)
            }
        } catch {
            print("Error checking exercises: \(error)")
        }
    }

    /// Seeds the database with system exercises with translations.
    @MainActor
    private static func seedSystemExercises(modelContext: ModelContext) {
        // First, get all body parts to reference by code
        let descriptor = FetchDescriptor<BodyPart>()
        guard let bodyParts = try? modelContext.fetch(descriptor) else {
            print("Error: Could not fetch body parts for exercise seeding")
            return
        }

        func bodyPartId(for code: String) -> UUID? {
            bodyParts.first { $0.code == code }?.id
        }

        // Exercise data: (code, defaultName, bodyPartCode, ja, en)
        let exercisesData: [(code: String, defaultName: String, bodyPartCode: String, ja: String, en: String)] = [
            // Chest
            ("bench_press", "Bench Press", "chest", "ベンチプレス", "Bench Press"),
            ("incline_bench_press", "Incline Bench Press", "chest", "インクラインベンチプレス", "Incline Bench Press"),
            ("decline_bench_press", "Decline Bench Press", "chest", "デクラインベンチプレス", "Decline Bench Press"),
            ("dumbbell_press", "Dumbbell Press", "chest", "ダンベルプレス", "Dumbbell Press"),
            ("dumbbell_fly", "Dumbbell Fly", "chest", "ダンベルフライ", "Dumbbell Fly"),
            ("cable_fly", "Cable Fly", "chest", "ケーブルフライ", "Cable Fly"),
            ("push_up", "Push Up", "chest", "プッシュアップ", "Push Up"),
            ("chest_dip", "Chest Dip", "chest", "チェストディップ", "Chest Dip"),
            ("pec_deck", "Pec Deck", "chest", "ペックデック", "Pec Deck"),

            // Back
            ("deadlift", "Deadlift", "back", "デッドリフト", "Deadlift"),
            ("barbell_row", "Barbell Row", "back", "バーベルロウ", "Barbell Row"),
            ("dumbbell_row", "Dumbbell Row", "back", "ダンベルロウ", "Dumbbell Row"),
            ("lat_pulldown", "Lat Pulldown", "back", "ラットプルダウン", "Lat Pulldown"),
            ("pull_up", "Pull Up", "back", "プルアップ", "Pull Up"),
            ("chin_up", "Chin Up", "back", "チンアップ", "Chin Up"),
            ("seated_row", "Seated Row", "back", "シーテッドロウ", "Seated Row"),
            ("t_bar_row", "T-Bar Row", "back", "Tバーロウ", "T-Bar Row"),
            ("face_pull", "Face Pull", "back", "フェイスプル", "Face Pull"),

            // Shoulders
            ("overhead_press", "Overhead Press", "shoulders", "オーバーヘッドプレス", "Overhead Press"),
            ("dumbbell_shoulder_press", "Dumbbell Shoulder Press", "shoulders", "ダンベルショルダープレス", "Dumbbell Shoulder Press"),
            ("lateral_raise", "Lateral Raise", "shoulders", "サイドレイズ", "Lateral Raise"),
            ("front_raise", "Front Raise", "shoulders", "フロントレイズ", "Front Raise"),
            ("rear_delt_fly", "Rear Delt Fly", "shoulders", "リアデルトフライ", "Rear Delt Fly"),
            ("arnold_press", "Arnold Press", "shoulders", "アーノルドプレス", "Arnold Press"),
            ("upright_row", "Upright Row", "shoulders", "アップライトロウ", "Upright Row"),
            ("shrug", "Shrug", "shoulders", "シュラッグ", "Shrug"),

            // Arms
            ("bicep_curl", "Bicep Curl", "arms", "バイセップカール", "Bicep Curl"),
            ("hammer_curl", "Hammer Curl", "arms", "ハンマーカール", "Hammer Curl"),
            ("preacher_curl", "Preacher Curl", "arms", "プリーチャーカール", "Preacher Curl"),
            ("tricep_extension", "Tricep Extension", "arms", "トライセップエクステンション", "Tricep Extension"),
            ("tricep_pushdown", "Tricep Pushdown", "arms", "トライセッププッシュダウン", "Tricep Pushdown"),
            ("skull_crusher", "Skull Crusher", "arms", "スカルクラッシャー", "Skull Crusher"),
            ("close_grip_bench", "Close Grip Bench Press", "arms", "ナローベンチプレス", "Close Grip Bench Press"),
            ("dip", "Dip", "arms", "ディップ", "Dip"),

            // Abs
            ("crunch", "Crunch", "abs", "クランチ", "Crunch"),
            ("sit_up", "Sit Up", "abs", "シットアップ", "Sit Up"),
            ("plank", "Plank", "abs", "プランク", "Plank"),
            ("leg_raise", "Leg Raise", "abs", "レッグレイズ", "Leg Raise"),
            ("hanging_leg_raise", "Hanging Leg Raise", "abs", "ハンギングレッグレイズ", "Hanging Leg Raise"),
            ("russian_twist", "Russian Twist", "abs", "ロシアンツイスト", "Russian Twist"),
            ("ab_wheel", "Ab Wheel", "abs", "アブローラー", "Ab Wheel"),
            ("cable_crunch", "Cable Crunch", "abs", "ケーブルクランチ", "Cable Crunch"),

            // Legs
            ("squat", "Squat", "legs", "スクワット", "Squat"),
            ("front_squat", "Front Squat", "legs", "フロントスクワット", "Front Squat"),
            ("leg_press", "Leg Press", "legs", "レッグプレス", "Leg Press"),
            ("leg_extension", "Leg Extension", "legs", "レッグエクステンション", "Leg Extension"),
            ("leg_curl", "Leg Curl", "legs", "レッグカール", "Leg Curl"),
            ("romanian_deadlift", "Romanian Deadlift", "legs", "ルーマニアンデッドリフト", "Romanian Deadlift"),
            ("lunge", "Lunge", "legs", "ランジ", "Lunge"),
            ("calf_raise", "Calf Raise", "legs", "カーフレイズ", "Calf Raise"),
            ("hack_squat", "Hack Squat", "legs", "ハックスクワット", "Hack Squat"),

            // Glutes
            ("hip_thrust", "Hip Thrust", "glutes", "ヒップスラスト", "Hip Thrust"),
            ("glute_bridge", "Glute Bridge", "glutes", "グルートブリッジ", "Glute Bridge"),
            ("cable_kickback", "Cable Kickback", "glutes", "ケーブルキックバック", "Cable Kickback"),
            ("sumo_deadlift", "Sumo Deadlift", "glutes", "スモウデッドリフト", "Sumo Deadlift"),
            ("bulgarian_split_squat", "Bulgarian Split Squat", "glutes", "ブルガリアンスクワット", "Bulgarian Split Squat"),

            // Full Body
            ("clean", "Clean", "full_body", "クリーン", "Clean"),
            ("clean_and_jerk", "Clean and Jerk", "full_body", "クリーン&ジャーク", "Clean and Jerk"),
            ("snatch", "Snatch", "full_body", "スナッチ", "Snatch"),
            ("thruster", "Thruster", "full_body", "スラスター", "Thruster"),
            ("burpee", "Burpee", "full_body", "バーピー", "Burpee"),
            ("kettlebell_swing", "Kettlebell Swing", "full_body", "ケトルベルスイング", "Kettlebell Swing"),

            // Cardio
            ("treadmill", "Treadmill", "cardio", "トレッドミル", "Treadmill"),
            ("cycling", "Cycling", "cardio", "サイクリング", "Cycling"),
            ("rowing", "Rowing", "cardio", "ローイング", "Rowing"),
            ("elliptical", "Elliptical", "cardio", "エリプティカル", "Elliptical"),
            ("jump_rope", "Jump Rope", "cardio", "縄跳び", "Jump Rope"),
            ("stair_climber", "Stair Climber", "cardio", "ステアクライマー", "Stair Climber"),
        ]

        for data in exercisesData {
            let exercise = Exercise.systemExercise(
                code: data.code,
                defaultName: data.defaultName,
                bodyPartId: bodyPartId(for: data.bodyPartCode),
                category: nil
            )
            exercise.addTranslation(locale: "ja", name: data.ja)
            exercise.addTranslation(locale: "en", name: data.en)
            modelContext.insert(exercise)
        }
    }

    // MARK: - Combined Seeding

    /// Seeds all system data (body parts and exercises) if needed.
    @MainActor
    static func seedSystemDataIfNeeded(modelContext: ModelContext) {
        seedSystemBodyPartsIfNeeded(modelContext: modelContext)
        seedSystemExercisesIfNeeded(modelContext: modelContext)
    }
}
