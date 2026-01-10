# Services 仕様書

## 1. WorkoutService

ワークアウト日、エントリ、セットの管理。

### メソッド一覧

#### getOrCreateWorkoutDay

```swift
@MainActor static func getOrCreateWorkoutDay(
    profileId: UUID,
    date: Date,
    mode: WorkoutMode = .free,
    routinePresetId: UUID? = nil,
    routineDayId: UUID? = nil,
    modelContext: ModelContext
) -> WorkoutDay
```

**ビジネスロジック:**
- 入力日付をstart-of-dayに正規化
- 既存のワークアウト日を検索（プロファイル + 正規化日付）
- 見つかれば既存を返す（1日1件の制約）
- なければ新規作成して挿入

**テストケース:**
- 同じ日付で2回呼び出しても同じオブジェクトを返す
- 異なる日付では新規作成
- 日付の正規化が正しく動作

---

#### getWorkoutDay

```swift
@MainActor static func getWorkoutDay(
    profileId: UUID,
    date: Date,
    modelContext: ModelContext
) -> WorkoutDay?
```

**ビジネスロジック:**
- 正規化日付でワークアウト日を検索
- 見つからなければnil

**テストケース:**
- 存在する日付でワークアウト日を取得
- 存在しない日付でnilを返す

---

#### getTodayWorkout

```swift
@MainActor static func getTodayWorkout(
    profileId: UUID,
    modelContext: ModelContext
) -> WorkoutDay?
```

**ビジネスロジック:**
- 現在日付でgetWorkoutDayを呼び出すラッパー

---

#### addEntry

```swift
@discardableResult static func addEntry(
    to workoutDay: WorkoutDay,
    exerciseId: UUID,
    plannedSetCount: Int = 0,
    source: EntrySource = .free
) -> WorkoutExerciseEntry
```

**ビジネスロジック:**
- 既存エントリの最大orderIndexを取得
- 次のorderIndex = max + 1
- 新規エントリを作成して追加

**テストケース:**
- 空のワークアウトに追加するとorderIndex = 0
- 既存エントリがあれば正しい順序で追加
- plannedSetCountが正しく設定される

---

#### removeEntry

```swift
static func removeEntry(
    _ entry: WorkoutExerciseEntry,
    from workoutDay: WorkoutDay
)
```

**ビジネスロジック:**
- workoutDay.removeEntry()に委譲

---

#### reorderEntries

```swift
static func reorderEntries(
    in workoutDay: WorkoutDay,
    from fromIndex: Int,
    to toIndex: Int
)
```

**ビジネスロジック:**
- ソート済みエントリを取得
- 両インデックスが範囲内か検証
- 範囲外なら何もしない
- 移動後、全エントリのorderIndexを再計算
- workoutDayをtouchして更新

**テストケース:**
- 正常な並び替え
- 無効なインデックスで何もしない
- orderIndexが連続して再計算される

---

#### logSet

```swift
@discardableResult static func logSet(
    for entry: WorkoutExerciseEntry,
    weight: Decimal,
    reps: Int,
    isCompleted: Bool = true
) -> WorkoutSet
```

**ビジネスロジック:**
- entry.createSet()に委譲
- デフォルトでisCompleted = true

**テストケース:**
- セットが作成されて追加される
- weight/repsが正しく設定される
- デフォルトでisCompleted = true

---

#### completeSet

```swift
static func completeSet(
    _ set: WorkoutSet,
    weight: Decimal? = nil,
    reps: Int? = nil
)
```

**ビジネスロジック:**
- weightが指定されていれば更新
- repsが指定されていれば更新
- set.complete()を呼び出し

**テストケース:**
- weight/repsを指定して更新
- nilを渡すと既存値を維持
- 完了状態がtrueになる

---

#### uncompleteSet

```swift
static func uncompleteSet(_ set: WorkoutSet)
```

**ビジネスロジック:**
- set.uncomplete()を呼び出し

---

#### deleteSet

```swift
static func deleteSet(_ set: WorkoutSet)
```

**ビジネスロジック:**
- set.softDelete()を呼び出し（DBから削除しない）

**テストケース:**
- isSoftDeletedがtrueになる
- DBから削除されない

---

#### restoreSet

```swift
static func restoreSet(_ set: WorkoutSet)
```

**ビジネスロジック:**
- ソフト削除されたセットを復元

---

#### updateSet

```swift
static func updateSet(
    _ set: WorkoutSet,
    weight: Decimal,
    reps: Int
)
```

**ビジネスロジック:**
- set.update()に委譲

---

#### getStatistics

```swift
static func getStatistics(
    for workoutDay: WorkoutDay
) -> (sets: Int, volume: Decimal, exercises: Int)
```

**ビジネスロジック:**
- WorkoutDayの計算プロパティから値を取得
- 完了セット数、総ボリューム、エクササイズ数を返す

---

## 2. ProfileService

プロファイル管理。

### メソッド一覧

#### getOrCreateProfile

```swift
@MainActor static func getOrCreateProfile(
    modelContext: ModelContext
) -> LocalProfile
```

**ビジネスロジック:**
- 全プロファイルを取得（0または1件）
- 存在すれば返す
- なければ新規作成
- 初回作成時にシステムデータをシード

**副作用:**
- ExerciseCreationService.seedSystemDataIfNeeded()を呼び出し

**テストケース:**
- 初回呼び出しで新規作成
- 2回目以降は既存を返す
- システムデータがシードされる

---

#### getProfile

```swift
@MainActor static func getProfile(
    modelContext: ModelContext
) -> LocalProfile?
```

---

#### setActivePlan

```swift
static func setActivePlan(
    _ profile: LocalProfile,
    planId: UUID?
)
```

**ビジネスロジック:**
- profile.activePlanIdを設定
- nilを渡すとフリーモード

---

#### clearActivePlan

```swift
static func clearActivePlan(_ profile: LocalProfile)
```

---

## 3. DateUtilities

日付関連のユーティリティ（純粋関数）。

### メソッド一覧

#### startOfDay

```swift
nonisolated static func startOfDay(_ date: Date) -> Date
```

**ビジネスロジック:**
- Calendar.current.startOfDay()を使用
- ローカルタイムの00:00:00に正規化

---

#### today

```swift
nonisolated static var today: Date
```

---

#### isSameDay

```swift
nonisolated static func isSameDay(_ date1: Date, _ date2: Date) -> Bool
```

---

#### isToday / isYesterday

```swift
nonisolated static func isToday(_ date: Date) -> Bool
nonisolated static func isYesterday(_ date: Date) -> Bool
```

---

#### addDays

```swift
nonisolated static func addDays(_ days: Int, to date: Date) -> Date?
```

**テストケース:**
- 正の日数で未来日
- 負の日数で過去日
- うるう年の境界

---

#### daysBetween

```swift
nonisolated static func daysBetween(_ from: Date, and to: Date) -> Int?
```

---

#### startOfWeek

```swift
nonisolated static func startOfWeek(containing date: Date) -> Date?
```

---

#### weekdayIndex

```swift
nonisolated static func weekdayIndex(for date: Date) -> Int
```

**ビジネスロジック:**
- ISO形式（0-6、月曜=0）に変換
- 公式: (weekday + 5) % 7

---

#### workoutDate

```swift
nonisolated static func workoutDate(for date: Date, transitionHour: Int) -> Date
```

**ビジネスロジック:**
- 時刻を抽出
- hour < transitionHour なら1日前を返す
- そうでなければ当日を返す

**テストケース:**
- transitionHour = 3 で午前2時 → 前日
- transitionHour = 3 で午前4時 → 当日
- transitionHour = 0 → 常に当日

---

#### todayWorkoutDate

```swift
nonisolated static func todayWorkoutDate(transitionHour: Int) -> Date
```

---

#### isWorkoutToday / isSameWorkoutDay

```swift
nonisolated static func isWorkoutToday(_ date: Date, transitionHour: Int) -> Bool
nonisolated static func isSameWorkoutDay(_ date1: Date, _ date2: Date, transitionHour: Int) -> Bool
```

---

#### formatShort / formatFull

```swift
nonisolated static func formatShort(_ date: Date) -> String  // "Mon, Dec 15"
nonisolated static func formatFull(_ date: Date) -> String   // "December 15, 2024"
```

---

## 4. ExerciseCreationService

エクササイズと部位の作成。

### エラー型

```swift
enum ExerciseCreationError: LocalizedError {
    case emptyName
    case duplicateExercise(existingId: UUID, existingName: String)
}
```

### メソッド一覧

#### createUserExercise

```swift
@MainActor static func createUserExercise(
    profile: LocalProfile,
    bodyPart: BodyPart,
    name: String,
    modelContext: ModelContext
) throws -> Exercise
```

**ビジネスロジック:**
1. 名前をトリム
2. 空名チェック → エラー
3. 名前を正規化
4. 同じ部位で重複チェック
5. 重複あり → エラー
6. エクササイズを作成して挿入

**テストケース:**
- 正常作成
- 空名でemptyNameエラー
- 重複名でduplicateExerciseエラー
- 大文字小文字の違いも重複とみなす

---

#### fetchBodyParts

```swift
@MainActor static func fetchBodyParts(
    for profile: LocalProfile,
    modelContext: ModelContext
) -> [BodyPart]
```

**ビジネスロジック:**
- sortOrder、名前でソート
- アーカイブされていない
- グローバル + ユーザー所有

---

#### fetchExercises

```swift
@MainActor static func fetchExercises(
    for bodyPart: BodyPart,
    profile: LocalProfile,
    modelContext: ModelContext
) -> [Exercise]
```

---

#### seedSystemDataIfNeeded

```swift
@MainActor static func seedSystemDataIfNeeded(modelContext: ModelContext)
```

**ビジネスロジック:**
- seedSystemBodyPartsIfNeeded()を呼び出し
- seedSystemExercisesIfNeeded()を呼び出し

---

#### seedSystemBodyParts (private)

**シードデータ:**
- chest (1, "胸")
- back (2, "背中")
- shoulders (3, "肩")
- arms (4, "腕")
- abs (5, "腹筋")
- legs (6, "脚")
- glutes (7, "お尻")
- full_body (8, "全身")
- cardio (9, "有酸素")

---

#### seedSystemExercises (private)

**シードデータ（一部）:**
- Chest: Bench Press, Incline Bench Press, Dumbbell Fly...
- Back: Deadlift, Barbell Row, Lat Pulldown, Pull Up...
- Shoulders: Overhead Press, Lateral Raise...
- Arms: Bicep Curl, Tricep Extension, Dip...
- Abs: Crunch, Sit Up, Plank, Leg Raise...
- Legs: Squat, Leg Press, Lunge, Calf Raise...
- Glutes: Hip Thrust, Glute Bridge...
- Full Body: Clean, Burpee, Kettlebell Swing...
- Cardio: Treadmill, Cycling, Rowing, Elliptical...

---

## 5. BodyPartCreationService

部位の作成。

### エラー型

```swift
enum BodyPartCreationError: LocalizedError {
    case emptyName
    case duplicateBodyPart(existingName: String)
}
```

### メソッド一覧

#### createUserBodyPart

```swift
@MainActor static func createUserBodyPart(
    profile: LocalProfile,
    name: String,
    modelContext: ModelContext
) throws -> BodyPart
```

**ビジネスロジック:**
1. 名前をトリム
2. 空名チェック
3. 正規化して重複チェック（グローバル + ユーザー）
4. 次のsortOrderを計算
5. ユーザー部位を作成

**テストケース:**
- 正常作成
- 空名でエラー
- グローバル部位と同じ名前でエラー
- ユーザー部位と同じ名前でエラー

---

## 6. CycleService

サイクル管理。

### メソッド一覧

#### createCycle

```swift
@MainActor @discardableResult static func createCycle(
    profileId: UUID,
    name: String,
    modelContext: ModelContext
) -> PlanCycle
```

---

#### getCycles

```swift
@MainActor static func getCycles(
    profileId: UUID,
    modelContext: ModelContext
) -> [PlanCycle]
```

**ビジネスロジック:**
- createdAt降順でソート（新しい順）

---

#### getActiveCycle

```swift
@MainActor static func getActiveCycle(
    profileId: UUID,
    modelContext: ModelContext
) -> PlanCycle?
```

**ビジネスロジック:**
- isActive == trueのサイクルを取得
- 複数あっても最初の1件

---

#### setActiveCycle

```swift
@MainActor static func setActiveCycle(
    _ cycle: PlanCycle,
    profileId: UUID,
    modelContext: ModelContext
)
```

**ビジネスロジック:**
1. 全サイクルを取得
2. 対象以外のサイクルを非アクティブ化
3. 対象サイクルをアクティブ化
4. 進捗トラッカーを確保

**テストケース:**
- 他のアクティブサイクルが非アクティブ化される
- 対象サイクルがアクティブになる
- 進捗トラッカーが作成される

---

#### deactivateCycle

```swift
@MainActor static func deactivateCycle(_ cycle: PlanCycle)
```

---

#### addPlan

```swift
@MainActor static func addPlan(
    to cycle: PlanCycle,
    plan: WorkoutPlan,
    modelContext: ModelContext
)
```

**ビジネスロジック:**
- 次のorder = 既存の最大order + 1
- PlanCycleItemを作成して追加

---

#### removeItem

```swift
@MainActor static func removeItem(
    _ item: PlanCycleItem,
    from cycle: PlanCycle,
    modelContext: ModelContext
)
```

**ビジネスロジック:**
- アイテムを削除
- インデックスを再計算

---

#### moveItems

```swift
@MainActor static func moveItems(
    in cycle: PlanCycle,
    fromOffsets: IndexSet,
    toOffset: Int
)
```

---

#### advance

```swift
@MainActor @discardableResult static func advance(
    cycle: PlanCycle,
    modelContext: ModelContext
) -> Bool
```

**ビジネスロジック:**
1. 進捗を確保
2. アイテムを取得、空なら失敗
3. 全プランをロード
4. 現在のプランを取得
5. プランが削除されていたら次の有効プランへ
6. プランが空（0日）なら次の有効プランへ
7. progress.advanceDay()を呼び出し
8. 日がオーバーフローしたら次のプランへ
9. 空プランをスキップ

**テストケース:**
- 正常に次の日に進む
- 最終日で次のプランに進む
- 最終プランで最初のプランに戻る
- 削除されたプランをスキップ
- 空プランをスキップ
- 空サイクルで失敗

---

#### changeDay

```swift
@MainActor @discardableResult static func changeDay(
    cycle: PlanCycle,
    workoutDay: WorkoutDay,
    to newDayIndex: Int,
    skipAndAdvance: Bool,
    modelContext: ModelContext
) -> Bool
```

**ビジネスロジック:**
1. 完了セットがあれば失敗
2. 現在のアイテムを取得
3. プランをロード
4. newDayIndexが範囲内か検証（1始まり）
5. 既存エントリを全削除
6. workoutDay.routineDayIdを更新
7. プラン日をワークアウトに展開
8. skipAndAdvanceなら進捗ポインタを更新

**テストケース:**
- 完了セットがあると失敗
- 新しい日に変更される
- 既存エントリが削除される
- skipAndAdvanceで進捗ポインタが更新

---

#### getCurrentPlanDay

```swift
@MainActor static func getCurrentPlanDay(
    for cycle: PlanCycle,
    modelContext: ModelContext
) -> (plan: WorkoutPlan, day: PlanDay)?
```

---

#### getCurrentStateInfo

```swift
@MainActor static func getCurrentStateInfo(
    for cycle: PlanCycle,
    modelContext: ModelContext
) -> (cycleName: String, planName: String, dayInfo: String)?
```

---

#### getPreviewDayInfo

```swift
@MainActor static func getPreviewDayInfo(
    cycle: PlanCycle,
    targetDate: Date,
    todayDate: Date,
    modelContext: ModelContext
) -> (dayIndex: Int, totalDays: Int, dayName: String?)?
```

**ビジネスロジック:**
- 現在の進捗をベースに
- 日数差を計算
- モジュロ演算でラップアラウンド

**制限:**
- プラン間の遷移は考慮しない（単純プレビュー）

---

## 7. PlanService

プラン管理。

### メソッド一覧

#### createPlan

```swift
@MainActor @discardableResult static func createPlan(
    profileId: UUID,
    name: String,
    modelContext: ModelContext
) -> WorkoutPlan
```

---

#### getPlans

```swift
@MainActor static func getPlans(
    profileId: UUID,
    includeArchived: Bool = false,
    modelContext: ModelContext
) -> [WorkoutPlan]
```

**ビジネスロジック:**
- createdAt降順でソート
- includeArchivedがfalseならアーカイブを除外

---

#### getPlan

```swift
@MainActor static func getPlan(
    id planId: UUID,
    modelContext: ModelContext
) -> WorkoutPlan?
```

---

#### getOrCreateProgress

```swift
@MainActor static func getOrCreateProgress(
    profileId: UUID,
    planId: UUID,
    modelContext: ModelContext
) -> PlanProgress
```

---

#### handleAppOpen

```swift
@MainActor static func handleAppOpen(
    profileId: UUID,
    planId: UUID,
    modelContext: ModelContext
) -> Int
```

**ビジネスロジック:**
1. プランを取得
2. 進捗を取得または作成
3. lastOpenedDateがnilなら今日に設定、現在日を返す
4. 同じ日なら現在日を返す
5. 異なる日なら前日完了をチェック
6. 完了していれば次の日に進む（ラップアラウンド）
7. lastOpenedDateを今日に更新
8. 日インデックスを返す（1始まり）

**テストケース:**
- 初回オープンで日1を返す
- 同じ日に再オープンで同じ日を返す
- 翌日オープンで前日完了なら進む
- 翌日オープンで前日未完了なら進まない

---

#### changeDay

```swift
@MainActor @discardableResult static func changeDay(
    profile: LocalProfile,
    workoutDay: WorkoutDay,
    planId: UUID,
    to newDayIndex: Int,
    skipAndAdvance: Bool,
    modelContext: ModelContext
) -> Bool
```

**ビジネスロジック:**
- CycleService.changeDay()と同様だがsingleモード用

---

#### expandPlanToWorkout

```swift
static func expandPlanToWorkout(
    planDay: PlanDay,
    workoutDay: WorkoutDay
)
```

**ビジネスロジック:**
1. プラン日の各エクササイズを処理
2. 計画セットを取得（あれば）
3. 有効セット数を決定
4. WorkoutExerciseEntryを作成
5. 計画セットがあれば各セットを作成（目標weight/reps付き）
6. なければプレースホルダーセットを作成

**テストケース:**
- 正しい数のエントリが作成される
- 正しい順序で作成される
- 計画セットの目標値が設定される
- セット数が正しい

---

#### setupTodayWorkout

```swift
@MainActor static func setupTodayWorkout(
    profile: LocalProfile,
    modelContext: ModelContext
) -> WorkoutDay?
```

**ビジネスロジック:**
1. アクティブプランがなければnil
2. 今日の日インデックスを取得
3. プランとプラン日を取得
4. 既存ワークアウトをチェック
   - 同じプラン日ならそのまま返す
   - 空でリンクなしならセットアップ
   - それ以外はそのまま返す
5. なければ新規作成（routineモード）
6. プランをワークアウトに展開

**テストケース:**
- アクティブプランなしでnil
- 既存ワークアウトがあればそのまま
- 新規ワークアウトが作成される
- エントリが正しく展開される

---

#### getDayInfo

```swift
@MainActor static func getDayInfo(
    planDayId: UUID,
    planId: UUID,
    modelContext: ModelContext
) -> (dayIndex: Int, totalDays: Int, dayName: String?)?
```

---

#### getPreviewDayInfo

```swift
@MainActor static func getPreviewDayInfo(
    profile: LocalProfile,
    targetDate: Date,
    todayDate: Date,
    modelContext: ModelContext
) -> (dayIndex: Int, totalDays: Int, dayName: String?, planId: UUID)?
```

---

#### getExercise

```swift
@MainActor static func getExercise(
    id exerciseId: UUID,
    modelContext: ModelContext
) -> Exercise?
```

---

#### getAvailableExercises

```swift
@MainActor static func getAvailableExercises(
    profileId: UUID,
    includeArchived: Bool = false,
    modelContext: ModelContext
) -> [Exercise]
```

**ビジネスロジック:**
- 全エクササイズを取得
- メモリ内でフィルタ（enum述語の制限のため）
- グローバル + ユーザー所有、非アーカイブ
- category、名前でソート
