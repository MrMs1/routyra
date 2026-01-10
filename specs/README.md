# Routyra テスト仕様書

このディレクトリには、Routyraアプリのテスト実装のための仕様書が含まれています。

## ファイル構成

| ファイル | 内容 |
|---------|------|
| [models.md](./models.md) | データモデルの仕様（プロパティ、メソッド、制約） |
| [services.md](./services.md) | サービス層の仕様（ビジネスロジック、副作用） |
| [ui-flows.md](./ui-flows.md) | UIフローと状態管理の仕様 |

## アーキテクチャ概要

```
LocalProfile (ユーザープロファイル)
├── WorkoutPlan (ワークアウトプラン)
│   └── PlanDay (プラン日)
│       └── PlanExercise (プランエクササイズ)
│           └── PlannedSet (計画セット)
│
├── PlanCycle (サイクル)
│   ├── PlanCycleItem (サイクルアイテム → WorkoutPlanを参照)
│   └── PlanCycleProgress (進捗)
│
├── WorkoutDay (ワークアウト日 = 1日1件)
│   └── WorkoutExerciseEntry (エクササイズエントリ)
│       └── WorkoutSet (セット)
│
├── PlanProgress (プラン進捗)
│
├── Exercise (エクササイズ定義)
│   └── ExerciseTranslation
│
└── BodyPart (部位)
    └── BodyPartTranslation
```

## 実行モード

| モード | 説明 |
|--------|------|
| `ExecutionMode.single` | 単一プラン実行モード |
| `ExecutionMode.cycle` | サイクル実行モード（複数プランをローテーション） |

## インデックス規則

| 対象 | インデックス方式 |
|------|-----------------|
| `PlanDay.dayIndex` | 1始まり（表示用） |
| `PlanExercise.orderIndex` | 0始まり |
| `WorkoutExerciseEntry.orderIndex` | 0始まり |
| `WorkoutSet.setIndex` | 1始まり（表示用） |
| `PlannedSet.orderIndex` | 0始まり |
| `PlanCycleItem.order` | 0始まり |
| `PlanProgress.currentDayIndex` | 1始まり |
| `PlanCycleProgress.currentDayIndex` | 0始まり |
| `PlanCycleProgress.currentItemIndex` | 0始まり |

## テスト優先度

### 高優先度
1. セットのログと完了フロー
2. 日変更（両モード、スキップあり/なし）
3. サイクル自動進行
4. エクササイズエントリ管理（追加/削除）
5. 重量/レップ状態の伝播
6. エントリ展開管理

### 中優先度
1. 空状態フロー
2. 前回ワークアウトのコピー
3. 実行モード切替
4. プラン/サイクル選択
5. Undo/スナックバーシステム

### 低優先度
1. 週間アクティビティ計算
2. ビジュアルフィードバック（アニメーション、ハプティクス）
3. エッジケースの日時処理
4. 設定の永続化
