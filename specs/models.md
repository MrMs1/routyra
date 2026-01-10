# Models 仕様書

## 1. LocalProfile

ユーザープロファイル。アプリ起動時に自動生成（認証不要）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `activePlanId` | `UUID?` | `nil` | アクティブなプランID（nilはフリーモード） |
| `executionMode` | `ExecutionMode` | `.single` | 実行モード |
| `dayTransitionHour` | `Int` | `3` | 日付切替時刻（0-23） |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `hasActivePlan` | `Bool` | アクティブなプランがあるか |

### ビジネスルール

- 初回起動時に1つ生成される
- `dayTransitionHour`が3の場合、午前3時前のワークアウトは前日としてカウント

---

## 2. BodyPart

部位定義（胸、背中など）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `code` | `String?` | `nil` | システム定義コード（chest, backなど） |
| `isSystem` | `Bool` | - | システム定義かどうか |
| `scope` | `ExerciseScope` | - | グローバル or ユーザー |
| `ownerProfileId` | `UUID?` | `nil` | 所有者プロファイルID |
| `name` | `String` | - | 表示名 |
| `normalizedName` | `String` | - | 正規化名（重複チェック用） |
| `sortOrder` | `Int` | 0/999 | ソート順 |
| `isArchived` | `Bool` | `false` | アーカイブ済みか |
| `translations` | `[BodyPartTranslation]` | `[]` | 翻訳（カスケード削除） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `updatedAt` | `Date` | 現在時刻 | 更新日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `localizedName` | `String` | ローカライズ名（現在ロケール → en → 最初の翻訳 → name → code） |
| `color` | `Color` | コードに基づく色（chest=赤, back=青など） |

### メソッド

| メソッド | 説明 |
|---------|------|
| `addTranslation(locale:name:)` | 翻訳を追加 |
| `translation(for:)` | 指定ロケールの翻訳を取得 |
| `touch()` | updatedAtを更新 |
| `archive()` | アーカイブ |
| `unarchive()` | アーカイブ解除 |

### ファクトリメソッド

| メソッド | 説明 |
|---------|------|
| `systemBodyPart(code:defaultName:sortOrder:)` | システム部位を作成 |
| `userBodyPart(name:profileId:sortOrder:)` | ユーザー部位を作成 |

### ビジネスルール

- 名前は初期化時にトリミングされる
- `normalizedName`は名前から自動計算（小文字、トリム、スペース圧縮）
- システム部位は`scope = .global`、ユーザー作成は`scope = .user`
- デフォルト`sortOrder`はシステム=0、ユーザー=999

---

## 3. Exercise

エクササイズ定義。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `code` | `String?` | `nil` | システム定義コード |
| `isSystem` | `Bool` | - | システム定義かどうか |
| `scope` | `ExerciseScope` | - | グローバル or ユーザー |
| `ownerProfileId` | `UUID?` | `nil` | 所有者プロファイルID |
| `bodyPartId` | `UUID?` | `nil` | 部位ID |
| `name` | `String` | - | 表示名 |
| `normalizedName` | `String` | - | 正規化名 |
| `category` | `String?` | `nil` | カテゴリ（後方互換用） |
| `isArchived` | `Bool` | `false` | アーカイブ済みか |
| `translations` | `[ExerciseTranslation]` | `[]` | 翻訳（カスケード削除） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `updatedAt` | `Date` | 現在時刻 | 更新日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `localizedName` | `String` | ローカライズ名 |

### メソッド

| メソッド | 説明 |
|---------|------|
| `addTranslation(locale:name:)` | 翻訳を追加 |
| `translation(for:)` | 指定ロケールの翻訳を取得 |
| `touch()` | updatedAtを更新 |
| `archive()` | アーカイブ |
| `unarchive()` | アーカイブ解除 |
| `updateName(_:)` | 名前を更新（normalizedNameも再計算） |

### ファクトリメソッド

| メソッド | 説明 |
|---------|------|
| `systemExercise(code:defaultName:bodyPartId:category:)` | システムエクササイズを作成 |
| `userExercise(name:profileId:bodyPartId:category:)` | ユーザーエクササイズを作成 |

---

## 4. WorkoutPlan

ワークアウトプラン（複数日のトレーニングプログラム）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `profileId` | `UUID` | - | 所有者プロファイルID |
| `name` | `String` | - | プラン名 |
| `note` | `String?` | `nil` | メモ |
| `isArchived` | `Bool` | `false` | アーカイブ済みか |
| `days` | `[PlanDay]` | `[]` | 日（カスケード削除） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `updatedAt` | `Date` | 現在時刻 | 更新日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `sortedDays` | `[PlanDay]` | dayIndex順にソート |
| `dayCount` | `Int` | 日数 |
| `totalExerciseCount` | `Int` | 全エクササイズ数 |
| `totalPlannedSets` | `Int` | 全計画セット数 |

### メソッド

| メソッド | 説明 |
|---------|------|
| `touch()` | updatedAtを更新 |
| `archive()` | アーカイブ |
| `unarchive()` | アーカイブ解除 |
| `addDay(_:)` | 日を追加 |
| `day(at:)` | インデックスで日を取得（1始まり） |
| `createDay(name:note:)` | 新しい日を作成して追加 |
| `removeDay(_:)` | 日を削除 |
| `reindexDays()` | 日のインデックスを再計算 |
| `duplicateDay(_:)` | 日を複製 |

### ビジネスルール

- `dayIndex`は1始まり
- `reindexDays()`はソート順に基づいて1から再番号付け

---

## 5. PlanDay

プランの1日分。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `plan` | `WorkoutPlan?` | - | 親プラン |
| `dayIndex` | `Int` | - | 日番号（1始まり） |
| `name` | `String?` | `nil` | 日名（Push, Pullなど） |
| `note` | `String?` | `nil` | メモ |
| `exercises` | `[PlanExercise]` | `[]` | エクササイズ（カスケード削除） |
| `exerciseGroups` | `[PlanExerciseGroup]` | `[]` | グループ（カスケード削除） |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `displayName` | `String` | 表示名（nameがなければ"Day N"） |
| `fullTitle` | `String` | 日番号と名前を含む完全タイトル |
| `sortedExercises` | `[PlanExercise]` | orderIndex順にソート |
| `exerciseCount` | `Int` | エクササイズ数 |
| `totalPlannedSets` | `Int` | 全計画セット数 |
| `summary` | `String` | 概要（"3種目 / 9セット"など） |

### メソッド

| メソッド | 説明 |
|---------|------|
| `addExercise(_:)` | エクササイズを追加 |
| `createExercise(exerciseId:plannedSetCount:)` | 新しいエクササイズを作成して追加 |
| `removeExercise(_:)` | エクササイズを削除 |
| `reindexExercises()` | エクササイズのインデックスを再計算 |
| `duplicate(newDayIndex:)` | ディープコピーを作成 |

### ビジネスルール

- `duplicate()`はエクササイズとそのセットも含めてコピー

---

## 6. PlanExerciseGroup

プラン内のエクササイズグループ（Superset/Giant）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `planDay` | `PlanDay?` | - | 親日 |
| `type` | `ExerciseGroupType` | `.superset` | グループ種別 |
| `orderIndex` | `Int` | - | 表示順（0始まり、日内） |
| `setCount` | `Int` | - | グループのセット数（ラウンド数） |
| `roundRestSeconds` | `Int?` | `nil` | ラウンド後の休憩（秒） |
| `exercises` | `[PlanExercise]` | `[]` | グループ内エクササイズ |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `sortedExercises` | `[PlanExercise]` | groupOrderIndex順にソート |
| `displayName` | `String` | 表示名（Superset/Giant） |

### メソッド

| メソッド | 説明 |
|---------|------|
| `addExercise(_:)` | エクササイズを追加 |
| `removeExercise(_:)` | エクササイズを削除 |
| `reindexExercises()` | グループ内順序を再計算 |
| `updateSetCount(_:)` | セット数を更新して全種目に同期 |

### ビジネスルール

- グループは2種目以上（2未満になったら自動解除）
- グループ内のセット数は`setCount`で統一
- 種目単位の休憩は持たず、休憩はラウンド後のみ
- 1つのPlanExerciseは最大1グループに所属

---

## 7. PlanExercise

プラン内のエクササイズ。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `planDay` | `PlanDay?` | - | 親日 |
| `exerciseId` | `UUID` | - | エクササイズ定義ID |
| `orderIndex` | `Int` | - | 表示順（0始まり） |
| `groupId` | `UUID?` | `nil` | 所属グループID（グループ化時のみ） |
| `groupOrderIndex` | `Int?` | `nil` | グループ内表示順（0始まり） |
| `plannedSetCount` | `Int` | - | 計画セット数（レガシー） |
| `plannedSets` | `[PlannedSet]` | `[]` | 詳細な計画セット（カスケード削除） |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `sortedPlannedSets` | `[PlannedSet]` | orderIndex順にソート |
| `effectiveSetCount` | `Int` | 有効セット数（plannedSetsがあればそのcount、なければplannedSetCount） |
| `setsSummary` | `String` | セット概要（"60kg / 10回 / 3セット"など） |
| `compactSummary` | `String` | コンパクト概要（"3 sets • 8–10 reps • 75–80kg"） |
| `isGrouped` | `Bool` | groupIdがあるか |

### メソッド

| メソッド | 説明 |
|---------|------|
| `updatePlannedSets(_:)` | 計画セット数を更新（レガシー） |
| `addPlannedSet(_:)` | 計画セットを追加 |
| `createPlannedSet(weight:reps:)` | 新しい計画セットを作成して追加 |
| `removePlannedSet(_:)` | 計画セットを削除 |
| `reindexPlannedSets()` | 計画セットのインデックスを再計算 |

### ビジネスルール

- `groupId`がある場合、セット数はグループの`setCount`に同期
- グループ化中は`groupOrderIndex`を使用し、`orderIndex`は未使用

---

## 8. PlannedSet

計画セット（目標重量/レップ）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `planExercise` | `PlanExercise?` | - | 親エクササイズ |
| `orderIndex` | `Int` | - | 順序（0始まり） |
| `targetWeight` | `Double?` | `nil` | 目標重量（kg） |
| `targetReps` | `Int?` | `nil` | 目標レップ |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `weightString` | `String` | 重量文字列 |
| `repsString` | `String` | レップ文字列 |
| `repsStringWithUnit` | `String` | 単位付きレップ文字列 |
| `summary` | `String` | 概要（"60kg / 10回"） |

### ビジネスルール

- `targetWeight`と`targetReps`は両方nilも可能
- nil重量は「前回と同じ」または「未指定」を意味

---

## 9. PlanCycle

プランサイクル（複数プランのローテーション）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `profileId` | `UUID` | - | 所有者プロファイルID |
| `name` | `String` | - | サイクル名 |
| `isActive` | `Bool` | `false` | アクティブかどうか |
| `items` | `[PlanCycleItem]` | `[]` | アイテム（カスケード削除） |
| `progress` | `PlanCycleProgress?` | `nil` | 進捗（カスケード削除） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `updatedAt` | `Date` | 現在時刻 | 更新日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `sortedItems` | `[PlanCycleItem]` | order順にソート |
| `planCount` | `Int` | プラン数 |
| `hasPlans` | `Bool` | プランがあるか |
| `currentPlan` | `WorkoutPlan?` | 現在のプラン |
| `currentDayIndex` | `Int` | 現在の日インデックス（0始まり） |
| `currentItem` | `PlanCycleItem?` | 現在のアイテム |

### メソッド

| メソッド | 説明 |
|---------|------|
| `touch()` | updatedAtを更新 |
| `addItem(_:)` | アイテムを追加 |
| `removeItem(_:)` | アイテムを削除 |
| `reindexItems()` | アイテムのインデックスを再計算（0始まり） |

### ビジネスルール

- プロファイルごとに1つだけアクティブにできる（アプリで制御）

---

## 10. PlanCycleItem

サイクル内のプラン参照。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `order` | `Int` | - | 順序（0始まり） |
| `cycle` | `PlanCycle?` | - | 親サイクル |
| `planId` | `UUID` | - | プランID |
| `note` | `String?` | `nil` | メモ |
| `plan` | `WorkoutPlan?` | `nil` | キャッシュされたプラン参照（一時的、永続化されない） |

---

## 11. PlanCycleProgress

サイクル進捗。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `cycle` | `PlanCycle?` | - | 親サイクル |
| `currentItemIndex` | `Int` | `0` | 現在のアイテムインデックス（0始まり） |
| `currentDayIndex` | `Int` | `0` | 現在の日インデックス（0始まり） |
| `lastAdvancedAt` | `Date?` | `nil` | 最終進行日時 |
| `lastCompletedAt` | `Date?` | `nil` | 最終完了日時 |

### メソッド

| メソッド | 説明 |
|---------|------|
| `reset()` | 進捗をリセット（両インデックスを0に、日付をクリア） |
| `advanceDay(totalDays:)` | 次の日に進む。プラン切替時はtrueを返す |
| `advancePlan(totalItems:)` | 次のプランに進む（ラップアラウンド） |
| `markCompleted()` | 完了をマーク |

### ビジネスルール

- `advanceDay()`は`currentDayIndex`をインクリメント、`totalDays`に達したら次のプランへ
- `advancePlan()`は`currentItemIndex`をインクリメント、`totalItems`に達したら0に戻る

---

## 12. PlanProgress

プラン進捗（単一プランモード用）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `profileId` | `UUID` | - | プロファイルID |
| `planId` | `UUID` | - | プランID |
| `currentDayIndex` | `Int` | `1` | 現在の日インデックス（1始まり） |
| `lastOpenedDate` | `Date?` | `nil` | 最終オープン日（初回はnil） |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `isNewDay` | `Bool` | 最終オープン日が今日と異なるか |

### メソッド

| メソッド | 説明 |
|---------|------|
| `advanceToNextDay(totalDays:)` | 次の日に進む（ラップアラウンド） |
| `updateLastOpenedDate()` | 最終オープン日を今日に更新 |

### ビジネスルール

- `currentDayIndex`は1始まり（表示用）
- `advanceToNextDay()`はモジュロ演算でラップアラウンド

---

## 13. WorkoutDay

ワークアウト日（1日1件の制約）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `profileId` | `UUID` | - | プロファイルID |
| `date` | `Date` | - | 日付（start-of-dayに正規化） |
| `mode` | `WorkoutMode` | - | ワークアウトモード（free/routine） |
| `routinePresetId` | `UUID?` | `nil` | ルーティンプリセットID（routineモード時） |
| `routineDayId` | `UUID?` | `nil` | ルーティン日ID（routineモード時） |
| `entries` | `[WorkoutExerciseEntry]` | `[]` | エントリ（カスケード削除） |
| `exerciseGroups` | `[WorkoutExerciseGroup]` | `[]` | グループ（カスケード削除） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `updatedAt` | `Date` | 現在時刻 | 更新日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `totalCompletedSets` | `Int` | 完了セット総数 |
| `totalExercisesWithSets` | `Int` | セットを持つエクササイズ数 |
| `totalVolume` | `Decimal` | 総ボリューム（重量×レップ） |
| `sortedEntries` | `[WorkoutExerciseEntry]` | orderIndex順にソート |
| `isRoutineCompleted` | `Bool` | ルーティンが完了したか |

### メソッド

| メソッド | 説明 |
|---------|------|
| `touch()` | updatedAtを更新 |
| `addEntry(_:)` | エントリを追加 |
| `removeEntry(_:)` | エントリを削除 |

### ビジネスルール

- プロファイルと日付の組み合わせで1件のみ（アプリで制御）
- `isRoutineCompleted`はルーティンモードで計画されたエクササイズがすべて完了した場合にtrue

---

## 14. WorkoutExerciseGroup

ワークアウト内のエクササイズグループ（Superset/Giant）。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `workoutDay` | `WorkoutDay?` | - | 親ワークアウト日 |
| `type` | `ExerciseGroupType` | `.superset` | グループ種別 |
| `orderIndex` | `Int` | - | 表示順（0始まり、日内） |
| `setCount` | `Int` | - | グループのセット数（ラウンド数） |
| `roundRestSeconds` | `Int?` | `nil` | ラウンド後の休憩（秒） |
| `entries` | `[WorkoutExerciseEntry]` | `[]` | グループ内エントリ |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `sortedEntries` | `[WorkoutExerciseEntry]` | groupOrderIndex順にソート |
| `displayName` | `String` | 表示名（Superset/Giant） |

### メソッド

| メソッド | 説明 |
|---------|------|
| `addEntry(_:)` | エントリを追加 |
| `removeEntry(_:)` | エントリを削除 |
| `reindexEntries()` | グループ内順序を再計算 |
| `updateRestSeconds(_:)` | ラウンド休憩を更新 |

### ビジネスルール

- ワークアウト中はグループ構成/セット数は変更不可
- 休憩はラウンド後のみ（種目単位の休憩は持たない）
- 1つのWorkoutExerciseEntryは最大1グループに所属

---

## 15. WorkoutExerciseEntry

ワークアウト内のエクササイズエントリ。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `workoutDay` | `WorkoutDay?` | - | 親ワークアウト日 |
| `exerciseId` | `UUID` | - | エクササイズ定義ID |
| `orderIndex` | `Int` | - | 表示順（0始まり） |
| `groupId` | `UUID?` | `nil` | 所属グループID（グループ化時のみ） |
| `groupOrderIndex` | `Int?` | `nil` | グループ内表示順（0始まり） |
| `source` | `EntrySource` | - | 追加元（routine/free） |
| `plannedSetCount` | `Int` | - | 計画セット数（0は目標なし） |
| `sets` | `[WorkoutSet]` | `[]` | セット（カスケード削除） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `activeSets` | `[WorkoutSet]` | ソフト削除されていないセット |
| `sortedSets` | `[WorkoutSet]` | setIndex順にソート |
| `completedSetsCount` | `Int` | 完了セット数 |
| `totalVolume` | `Decimal` | 完了セットの総ボリューム |
| `isPlannedSetsCompleted` | `Bool` | 全アクティブセットが完了か |
| `hasCompletedSets` | `Bool` | 完了セットがあるか |
| `nextSetIndex` | `Int` | 次のセットインデックス |

### メソッド

| メソッド | 説明 |
|---------|------|
| `addSet(_:)` | セットを追加 |
| `createSet(weight:reps:isCompleted:)` | 新しいセットを作成して追加 |
| `createPlaceholderSets(defaultWeight:defaultReps:)` | プレースホルダーセットを作成 |

### ビジネスルール

- `activeSets`はソフト削除されたセットを除外
- `isPlannedSetsCompleted`はセットがない場合はfalse
- `createPlaceholderSets()`は`plannedSetCount`まで補充
- `groupId`がある場合、`plannedSetCount`はグループの`setCount`に同期

---

## 16. WorkoutSet

ワークアウトセット。

### プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `entry` | `WorkoutExerciseEntry?` | - | 親エントリ |
| `setIndex` | `Int` | - | セット番号（1始まり、表示用） |
| `weight` | `Decimal` | - | 重量（kg、62.5kgなど小数対応） |
| `reps` | `Int` | - | レップ数 |
| `isCompleted` | `Bool` | `false` | 完了したか |
| `isSoftDeleted` | `Bool` | `false` | ソフト削除フラグ（undo用） |
| `createdAt` | `Date` | 現在時刻 | 作成日時 |
| `updatedAt` | `Date` | 現在時刻 | 更新日時 |

### 計算プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `volume` | `Decimal` | ボリューム（weight × reps） |
| `weightDouble` | `Double` | Double型の重量（UI用） |

### メソッド

| メソッド | 説明 |
|---------|------|
| `touch()` | updatedAtを更新 |
| `complete()` | 完了をマーク |
| `uncomplete()` | 完了を解除 |
| `toggleCompletion()` | 完了状態をトグル |
| `softDelete()` | ソフト削除 |
| `restore()` | ソフト削除から復元 |
| `update(weight:reps:)` | 重量とレップを更新 |
| `update(weightDouble:reps:)` | Double型重量とレップを更新 |

### ビジネスルール

- `weight`はDecimalで精度を保持（62.5kgなど）
- `isSoftDeleted`はundo機能のために永久削除ではなく使用
- `isCompleted`と`isSoftDeleted`は独立した状態

---

## 17. Enums

### ExecutionMode

```swift
enum ExecutionMode: String, Codable, CaseIterable {
    case single  // 単一プランモード
    case cycle   // サイクルモード
}
```

### ExerciseScope

```swift
enum ExerciseScope: String, Codable, CaseIterable {
    case global  // システム定義
    case user    // ユーザー作成
}
```

### ExerciseGroupType

```swift
enum ExerciseGroupType: String, Codable, CaseIterable {
    case superset
    case giantSet
}
```

### WorkoutMode

```swift
enum WorkoutMode: String, Codable, CaseIterable {
    case free     // フリーモード（アドホック）
    case routine  // ルーティンモード（プランから）
}
```

### EntrySource

```swift
enum EntrySource: String, Codable, CaseIterable {
    case routine  // ルーティンから自動追加
    case free     // 手動追加
}
```
