# UI フロー仕様書

## 1. メイン画面構造

### MainTabView

4つのタブで構成されるメイン画面。

```
[ Workout ] [ History ] [ Routines ] [ Settings ]
    (0)        (1)         (2)          (3)
```

| タブ | 説明 |
|------|------|
| Workout | ワークアウトログ画面（メイン） |
| History | 過去のワークアウト履歴 |
| Routines | プラン・サイクル管理 |
| Settings | 設定・エクササイズ管理 |

### プログラマティック ナビゲーション

WorkoutViewから他のタブへの遷移:
- `navigateToHistory = true` → Historyタブへ
- `navigateToRoutines = true` → Routinesタブへ

**テストケース:**
- タブ切替が正しく動作
- プログラマティック遷移が動作
- タブ切替後も状態が保持される

---

## 2. WorkoutView - ワークアウト画面

最も複雑なビュー。セットログ、日変更、サイクル進行を管理。

### 2.1 状態管理

#### 日付関連

| 状態 | 型 | 説明 |
|------|-----|------|
| `selectedDate` | `Date` | 選択中の日付 |
| `selectedWorkoutDate` | `Date` (computed) | start-of-dayに正規化 |
| `todayWorkoutDate` | `Date` (computed) | dayTransitionHourを考慮 |
| `isViewingToday` | `Bool` (computed) | 今日を表示中か |

#### エントリ/セット関連

| 状態 | 型 | 説明 |
|------|-----|------|
| `expandedEntryId` | `UUID?` | 展開中のエントリID |
| `currentWeight` | `Double` | 全エントリ共通の重量 |
| `currentReps` | `Int` | 全エントリ共通のレップ |

#### サイクル/プラン関連

| 状態 | 型 | 説明 |
|------|-----|------|
| `activeCycle` | `PlanCycle?` | アクティブなサイクル |
| `cycleStateInfo` | Tuple? | サイクル状態情報 |

### 2.2 実行モード

#### Singleモード

- `profile.activePlanId`でアクティブプランを決定
- `PlanService.setupTodayWorkout()`でセットアップ
- DayContextViewでプラン日の進捗を表示

#### Cycleモード

- アクティブサイクルとその進捗をロード
- 新しい日付で自動進行
- CycleContextViewでサイクル状態と「完了&進行」ボタンを表示

**テストケース:**
- 正しいモードでセットアップされる
- モード切替後に正しいコンテキストビューが表示される

---

### 2.3 日変更フロー

#### 状態

| 状態 | 型 | 説明 |
|------|-----|------|
| `showDayChangeDialog` | `Bool` | ダイアログ表示フラグ |
| `pendingDayChange` | `Int?` | 変更先の日インデックス |
| `skipCurrentDay` | `Bool` | スキップ&進行フラグ |

#### 変更可能条件

```swift
var canChangeDay: Bool {
    // プランが1日だけなら変更不可
    guard totalDays > 1 else { return false }

    // ワークアウトがまだなければ変更可
    guard let workoutDay = selectedWorkoutDay else { return true }

    // 完了セットがあれば変更不可
    return workoutDay.totalCompletedSets == 0
}
```

#### フロー

1. DayContextViewの前/次ボタンをタップ
2. `requestDayChange(to:)`が呼ばれる
3. `canChangeDay`がtrueならダイアログを表示
4. ダイアログで「スキップ&進行」トグルを選択可能
5. 確認で`executeDayChange()`を実行
   - Singleモード: `PlanService.changeDay()`
   - Cycleモード: `CycleService.changeDay()`
6. 成功時:
   - 最初のエントリを展開
   - Undoスナックバーを表示
7. `undoDayChange()`でundo可能

**テストケース:**
- 完了セットがあると変更不可
- 1日のプランでは変更不可
- ダイアログが正しく表示/非表示
- skipAndAdvanceでポインタが更新される
- Undoで元に戻る

---

### 2.4 エントリ管理

#### エントリ追加

1. 空状態から「エクササイズ追加」
2. 下部の「エクササイズ追加カード」から
3. フロー: `exercisePicker` → `setEditor` → `addExerciseToWorkout()`

#### セットログ

```swift
func logSet(for entry) -> Bool {
    // 次の未完了セットを見つける
    // 現在のweight/repsで完了マーク
    // 全セット完了なら次の未完了エントリを展開
    // 成功を返す
}
```

#### セット管理

| 操作 | 説明 |
|------|------|
| `addSet(to:)` | 新しい空セットを作成 |
| `removePlannedSet()` | 未完了セットをソフト削除（1セット以上必要） |
| `deleteCompletedSet()` | 完了セットをソフト削除（1セット以上必要） |
| `deleteEntry()` | エントリ全体を削除、次のエントリを展開 |

#### エクササイズ変更

- セットが完了していない場合のみ可能
- フロー: `exerciseChanger`ピッカー → `changeExercise()`

**テストケース:**
- セットログでweight/repsが更新される
- 全セット完了で次のエントリが展開される
- 最後のセットは削除不可
- セット完了後はエクササイズ変更不可

#### グループエントリ（Superset/Giant）

グループ内の複数種目を「1ラウンド」として扱い、ラウンド終了後に休憩を入れる。

表示:
- グループカード（Superset/Giantラベル、セット数、ラウンド後休憩）
- その下に種目カードをインデントして表示
- 種目カードは重量/回数編集のみ（個別休憩は表示しない）

ログ進行:
- 1ラウンド = グループ内の各種目を1セットずつ完了
- ラウンド完了時にグループ休憩を提示
- 次の未完了種目に自動フォーカス（グループ内優先）

編集制限（Workout）:
- グループ解除/構成変更/セット数変更は不可
- 編集できるのは重量/回数と「グループ休憩」だけ

**テストケース:**
- ラウンド完了時に休憩が提示される
- グループ内の次の種目へ自動展開される
- Workoutでグループ解除が表示されない

---

### 2.5 サイクル進行

#### 自動進行

```swift
func checkAndAutoAdvanceCycle(workoutDate:) {
    // 最後のワークアウトが異なる日で完了していれば
    // CycleService.advance()を呼び出し
}
```

#### 手動進行

1. CycleContextViewの「完了&進行」ボタンをタップ
2. `completeAndAdvanceCycle()`が呼ばれる
3. `cycle.progress?.markCompleted()`
4. `CycleService.advance()`
5. `cycleStateInfo`を更新

**テストケース:**
- 完了後の翌日で自動進行
- 手動完了ボタンで進行
- 同じ日に再進行しない

---

### 2.6 週間アクティビティストリップ

状態: `weeklyProgress: [Int: Double]`

- 現在週のワークアウトから計算
- 日インデックス(0-6)を完了率にマッピング
- 計算: `completedSets / totalSets`

**テストケース:**
- 進捗計算が正確
- 日選択でselectedDateが更新

---

### 2.7 スナックバー/Undoシステム

| 状態 | 型 | 説明 |
|------|-----|------|
| `snackBarMessage` | `String?` | 表示メッセージ |
| `snackBarUndoAction` | `(() -> Void)?` | Undoアクション |

動作:
- 4秒後に自動消去
- Undoタップでアクションを実行
- weight/reps調整ボタンも提供

**テストケース:**
- スナックバーが表示/消去される
- Undoが正しく実行される

---

## 3. RoutinesView - ルーティン画面

### 3.1 実行モード選択

セグメントピッカー: 「シングルプラン」/「サイクル」

- `profile.executionMode`に保存
- 即座にmodelContextに永続化

### 3.2 Singleプランモード

| コンポーネント | 説明 |
|--------------|------|
| アクティブプランピッカー | 現在のプラン or 「未設定」を表示 |
| 確認ダイアログ | 全プラン + 「なし」オプション |

操作:
- `setActivePlan()` - activePlanIdを更新
- `clearActivePlan()` - nilに設定

### 3.3 Cycleモード

| コンポーネント | 説明 |
|--------------|------|
| サイクルトグル | アクティブ/非アクティブ |
| サマリー | プラン名を「→」で連結 |
| 「サイクル編集」ボタン | CycleListViewへ遷移 |

### 3.4 プラン管理

#### プラン作成

1. ダイアログでプラン名を入力
2. 新規プラン作成（デフォルト1日付き）
3. PlanEditorViewへ自動遷移

#### プラン一覧

各プランに表示:
- 名前
- 「ACTIVE」バッジ（Singleモードでアクティブな場合）
- 日数
- エクササイズ数
- メモ（オプション）

#### プラン削除

- コンテキストメニュー or スワイプ
- Singleモードでアクティブなら警告
- 全サイクルから削除
- activePlanIdをクリア（アクティブなプランを削除した場合）

**テストケース:**
- プラン作成で名前が空でないことを検証
- 削除で適切な警告が表示される
- サイクルから削除される
- activePlanIdがクリアされる

### 3.5 PlanEditorView - Day編集（グループ）

Superset/Giantのために複数種目をグループ化して登録する。

#### グループ化フロー

1. Day編集の種目カードメニューから「グループ化」
2. 追加する種目を複数選択（2種目以上）
3. セット数が一致:
   - そのままグループを作成
4. セット数が不一致:
   - 「最大値に合わせる / 最小値に合わせる / 手動で指定」ダイアログ
   - 選択値をグループのセット数として全種目に同期

#### グループ表示/編集

- グループヘッダーに「種別（Superset/Giant）・セット数・休憩」を表示
- セット数はグループ側でのみ編集可能（各種目のセット数は編集不可）
- 休憩は「ラウンド後の休憩」のみ（種目単位の休憩は持たない）

#### 解除/変更

- Day編集ではグループ解除が可能
- 種目を削除して2種目未満になった場合は自動解除

**テストケース:**
- セット数不一致で揃え方ダイアログが表示される
- グループセット数の変更が全種目に同期される
- Workout側でグループ解除ができない

---

## 4. キーユーザーフロー

### 4.1 初回ワークアウト開始

1. Workoutタブを開く
2. onAppearが発火
3. プロファイルをロード
4. 実行モードをチェック
5. Singleモード: `PlanService.setupTodayWorkout()`
6. Cycleモード: `CycleService.getCurrentPlanDay()`
7. 空のWorkoutDayを作成（なければ）
8. 空状態を表示:
   - 「プラン作成」→ Routinesへ
   - 「前回をコピー」（前回あれば）
   - 「エクササイズ追加」

**テストケース:**
- 正しいモードでセットアップされる
- 空状態オプションが表示される
- ナビゲーションが正しく動作

---

### 4.2 セットログフロー

1. エントリが展開される
2. セットドット表示（完了/アクティブ/未来）
3. weight/reps入力フィールド
4. 「セットログ」ボタン
5. ユーザーがweight/repsを調整
6. 「セットログ」をタップ
7. `logSet()`が次の未完了セットを見つける
8. weight/repsを更新してマーク
9. 全セット完了で次の未完了エントリを展開
10. ハプティックフィードバック
11. 成功アニメーション
12. ステータスバーが更新される

**テストケース:**
- weight/repsがセットに記録される
- 自動展開とスクロールが動作
- ステータスバーが正確に更新される
- 全セット完了後のログ不可

---

### 4.3 サイクル内での日変更

シナリオ: 6日中2日目を表示中、4日目にジャンプしたい

1. 次ボタンを複数回タップ
2. DayContextViewにステッパーボタン
3. `canChangeDay`をチェック
4. `requestDayChange(to:)`を呼び出し
5. ダイアログを表示
   - ターゲット日番号
   - 「スキップ&進行」トグル
   - キャンセル/確認ボタン
6. 確認（skip=true）
7. `executeDayChange(to:, skipAndAdvance: true)`
8. サービスが新しいプラン日を決定
9. 前のエントリを削除
10. 新しいプラン日をエントリに展開
11. Cycleモード: `CycleService.changeDay()`
12. サイクル状態をリロード
13. 最初のエントリを展開
14. Undoスナックバーを表示
15. Undo可能（前のroutineDayId、エントリ、ポインタを復元）

**テストケース:**
- canChangeDay=trueでのみボタンが表示される
- ダイアログが正しいターゲット日を表示
- スキップトグルで進捗が更新される
- 日変更が両モードで成功
- 前のエントリが削除されて置き換えられる
- Undoで完全復元
- ラップアラウンド（6日目→次=1日目）

---

### 4.4 サイクル進行

シナリオ: 現在のプラン日を完了してサイクルを進行

#### 自動進行

1. 前回のカレンダー日にワークアウトを完了
2. 次のカレンダー日に戻る
3. `ensureTodayWorkout()`が呼ばれる
4. `checkAndAutoAdvanceCycle()`をチェック
5. 前回の完了日が前日なら:
   - `CycleService.advance()`
   - cycleStateInfoを更新

#### 手動進行

1. 「完了&進行」ボタンをタップ
2. 今日 + アクティブサイクルでのみ表示
3. `completeAndAdvanceCycle()`:
   - `progress.markCompleted()`
   - `CycleService.advance()`
   - `cycleStateInfo`を更新
4. スナックバー確認

#### 次回ワークアウトセットアップ

1. 現在のサイクル位置から新しいプラン日をロード
2. `setupWorkoutFromCycle()`がエントリを作成
3. 通常通り展開

**テストケース:**
- 完了後の新しい日でのみ自動進行
- 手動完了ボタンで即座に進行
- 進捗ポインタが次のアイテムに移動
- 新しいプラン日のエントリが正しくロード
- 同じ日に再進行しない
- CycleContextViewが今日+アクティブサイクルでのみ表示

---

### 4.5 実行モード切替

シナリオ: SingleモードからCycleモードへ切替

1. RoutinesViewで
2. 実行モードピッカーで「Cycle」を選択
3. `profile.executionMode = .cycle`を保存
4. Singleプランセクションがサイクルセクションに置き換わる
5. WorkoutViewで（次回表示時またはリフレッシュ時）
6. `ensureTodayWorkout()`が再評価
7. Singleモードブランチをスキップ
8. Cycleモードブランチを実行
9. アクティブサイクルがあれば:
   - `setupWorkoutFromCycle()`
   - 現在のサイクル位置からエントリをロード
10. アクティブサイクルがなければ:
    - 空のワークアウトを作成
11. DayContextViewが非表示（アクティブサイクルなければ）
12. CycleContextViewが表示（アクティブサイクル+今日なら）

**テストケース:**
- モード切替がプロファイルに永続化
- WorkoutViewがモード変更を検出
- 新モードで正しいセットアップ関数が呼ばれる
- コンテキスト表示が更新
- 正しいソースからエントリがロード
- 前のモードからの状態が残らない

---

## 5. コンポーネントレベル状態管理

### 5.1 ExerciseEntryCardView

| 内部状態 | 説明 |
|---------|------|
| `selectedSetIndex` | 選択中のセットインデックス |
| `logSuccessPulse` | アニメーショントリガー |
| `showDeleteEntryConfirmation` | 削除確認ダイアログ |
| `swipeOffset` | スワイプジェスチャー位置 |
| `isSwipeOpen` | スワイプ状態 |

| 計算プロパティ | 説明 |
|--------------|------|
| `activeSetIndex` | 最初の未完了セット |
| `allSetsCompleted` | 全セット完了か |
| `hasCompletedSets` | 完了セットがあるか |
| `canChangeExercise` | エクササイズ変更可能か |
| `isViewingCompletedSet` | 選択<アクティブインデックス |

動作:
- 左スワイプで削除ボタン表示
- 未来セットの長押しで削除
- 完了セットタップで選択
- 展開時にアクティブセットを自動選択

---

### 5.2 DayContextView

入力:
- `currentDayIndex: Int`
- `totalDays: Int`
- `dayName: String?`
- `canChangeDay: Bool`

動作:
- canChangeDayがtrueでのみステッパーボタン表示
- 日はラップアラウンド（6→1、1→6）
- canChangeDay=falseで「開始済み」バッジ表示
- プランラベルはタップ可能（ハンドラあれば）

---

## 6. データ永続化と一貫性

### 不変条件

1. プロファイルごとに1つのサイクルのみアクティブ
2. サイクルがアクティブなら、Singleモードのプランは無視
3. 完了セットは必ずweight/repsを持つ
4. エントリは少なくとも1セットを持つ
5. WorkoutDayは存在するexerciseIdを参照
6. 進捗ポインタはプラン日の範囲内

### テストが必要な操作

- 各主要操作後のデータ一貫性チェック
- 孤立したエントリ/セットがないこと
- 削除後も参照が有効
- 進捗ポインタが範囲内

---

## 7. エッジケース

### 日付/時刻境界

- dayTransitionHourの設定がプロファイルからロード
- 遷移時刻前の日付は前日として扱う
- 週間アクティビティストリップは遷移時刻に合わせる

### エントリ展開状態

- 同時に1つのエントリのみ展開可能
- 日付変更で最初のエントリを自動展開
- セット完了で次の未完了エントリを自動展開
- エントリ削除で次のエントリを展開

### weight/reps永続化

- `currentWeight`と`currentReps`は全エントリで共有
- あるエントリでの変更は全エントリに影響
- 更新タイミング:
  - エントリ展開時: 次の未完了セットの値を使用
  - セットログ時: 次のセットのために維持
  - スナックバー調整: 差分を適用

### 空エントリと削除

- エントリの最後のセットは削除不可
- エントリごとに少なくとも1セット必要
- 最後のエントリ削除で確認ダイアログ
- 次のエントリを展開（あれば）

### エクササイズ変更制限

- セットが完了していない場合のみ変更可能
- セットログ後は変更ボタン無効/非表示
- exerciseChangerへのナビゲーションもブロック
