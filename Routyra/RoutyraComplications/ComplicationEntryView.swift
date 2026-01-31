//
//  ComplicationEntryView.swift
//  RoutyraComplications
//
//  Views for watch complications.
//

import SwiftUI
import WidgetKit

struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ComplicationEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularComplicationView(entry: entry)
            case .accessoryCorner:
                CornerComplicationView(entry: entry)
            case .accessoryRectangular:
                RectangularComplicationView(entry: entry)
            default:
                EmptyView()
            }
        }
        // watchOS 10+: containerBackground で背景を設定
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Circular (インフォグラフ四隅)
// 円形プログレス + 中央に残り時間

struct CircularComplicationView: View {
    let entry: ComplicationEntry

    /// 実効的な状態（running で終了済みなら alarm として扱う）
    private var effectiveState: SharedTimerStateValue {
        if entry.timerState.state == .running,
           let endDate = entry.timerState.endDate,
           endDate <= Date() {
            return .alarm
        }
        return entry.timerState.state
    }

    var body: some View {
        switch effectiveState {
        case .running:
            // タイマー進行中: 円形プログレス + 残り時間
            if let endDate = entry.timerState.endDate {
                let startDate = endDate.addingTimeInterval(-Double(entry.timerState.totalDuration))
                ProgressView(timerInterval: startDate...endDate, countsDown: false) {
                    // Label（非表示）
                } currentValueLabel: {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .progressViewStyle(.circular)
                .tint(.blue)
            } else {
                // endDate が nil の場合のフォールバック
                Text("--:--")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

        case .alarm:
            // アラーム時: ベルアイコン
            Image(systemName: "bell.fill")
                .font(.title2)
                .foregroundStyle(.red)

        case .idle:
            // アイドル時: アプリアイコン
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .widgetAccentable()
        }
    }
}

// MARK: - Corner (インフォグラフ角)
// スペース制約のため、残り時間テキストのみ

struct CornerComplicationView: View {
    let entry: ComplicationEntry

    /// 実効的な状態（running で終了済みなら alarm として扱う）
    private var effectiveState: SharedTimerStateValue {
        if entry.timerState.state == .running,
           let endDate = entry.timerState.endDate,
           endDate <= Date() {
            return .alarm
        }
        return entry.timerState.state
    }

    var body: some View {
        switch effectiveState {
        case .running:
            // タイマー進行中: 数字カウントダウンのみ
            if let endDate = entry.timerState.endDate {
                Text(timerInterval: Date()...endDate, countsDown: true)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text("REST")
                    }
            } else {
                // endDate が nil の場合のフォールバック
                Text("--:--")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text("REST")
                    }
            }

        case .alarm:
            // アラーム時
            Image(systemName: "bell.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .widgetLabel {
                    Text("終了!")
                }

        case .idle:
            // アイドル時
            Image(systemName: "dumbbell.fill")
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    Text("Routyra")
                }
        }
    }
}

// MARK: - Rectangular (インフォグラフモジュラー大)
// 線形プログレスバー + 残り時間テキスト

struct RectangularComplicationView: View {
    let entry: ComplicationEntry

    /// 実効的な状態（running で終了済みなら alarm として扱う）
    private var effectiveState: SharedTimerStateValue {
        if entry.timerState.state == .running,
           let endDate = entry.timerState.endDate,
           endDate <= Date() {
            return .alarm
        }
        return entry.timerState.state
    }

    var body: some View {
        switch effectiveState {
        case .running:
            // タイマー進行中: プログレスバー + 残り時間
            if let endDate = entry.timerState.endDate {
                let startDate = endDate.addingTimeInterval(-Double(entry.timerState.totalDuration))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "timer")
                        Text("レスト中")
                            .font(.headline)
                        Spacer()
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .widgetAccentable()

                    // 線形プログレスバー（自動アニメーション）
                    ProgressView(timerInterval: startDate...endDate, countsDown: false)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
            } else {
                // endDate が nil の場合のフォールバック
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "timer")
                        Text("レスト中")
                            .font(.headline)
                        Spacer()
                        Text("--:--")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .widgetAccentable()
                }
            }

        case .alarm:
            // アラーム時: 終了表示
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.red)
                    Text("レスト終了!")
                        .font(.headline)
                }

                Text("次のセットへ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .idle:
            // アイドル時
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .widgetAccentable()

                VStack(alignment: .leading) {
                    Text("Routyra")
                        .font(.headline)
                    Text("タップして開始")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Circular - Idle", as: .accessoryCircular) {
    RoutyraComplications()
} timeline: {
    ComplicationEntry(date: Date(), timerState: .defaultState)
}

#Preview("Circular - Running", as: .accessoryCircular) {
    RoutyraComplications()
} timeline: {
    ComplicationEntry(
        date: Date(),
        timerState: SharedTimerState(
            endDate: Date().addingTimeInterval(90),
            totalDuration: 120,
            state: .running
        )
    )
}

#Preview("Rectangular - Running", as: .accessoryRectangular) {
    RoutyraComplications()
} timeline: {
    ComplicationEntry(
        date: Date(),
        timerState: SharedTimerState(
            endDate: Date().addingTimeInterval(90),
            totalDuration: 120,
            state: .running
        )
    )
}
