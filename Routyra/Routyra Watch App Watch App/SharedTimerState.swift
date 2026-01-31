//
//  SharedTimerState.swift
//  Routyra Watch App Watch App
//
//  Shared timer state for Watch App and Widget Extension communication.
//  This file should be added to both targets via Target Membership.
//

import Foundation
import WidgetKit

// MARK: - Shared Timer State Value

/// Codable対応のタイマー状態enum
enum SharedTimerStateValue: String, Codable {
    case idle
    case running
    case alarm
}

// MARK: - Shared Timer State

/// App Groups経由でWatch AppとWidget間で共有するタイマー状態
struct SharedTimerState: Codable {
    let endDate: Date?
    let totalDuration: Int
    let state: SharedTimerStateValue

    static let defaultState = SharedTimerState(
        endDate: nil,
        totalDuration: 0,
        state: .idle
    )
}

// MARK: - Shared Timer State Manager

/// Watch App と Widget Extension 両方で使用する読み書きユーティリティ
/// 注意: reloadTimelines() は Watch App 側からのみ呼び出すこと
enum SharedTimerStateManager {
    private static let appGroupID = "group.com.mrms.routyra"
    private static let stateKey = "sharedTimerState"
    static let complicationKind = "RoutyraTimerComplication"

    /// 状態を保存（Widget 更新なし - Watch App / Widget 両方から呼べる）
    static func save(_ state: SharedTimerState) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
            // synchronize() は非推奨のため呼ばない
            // Widget 側は「最新でない可能性」を前提にフォールバック
        }
    }

    /// 状態を読み込み（フォールバック付き）
    /// Widget 側から呼ばれる想定。古い値が返る可能性を考慮した設計。
    static func load() -> SharedTimerState {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(SharedTimerState.self, from: data)
        else {
            return .defaultState
        }

        // フォールバック: running 状態で終了時刻が過去の場合
        // → 実際は alarm 状態のはず。alarm として扱う（ユーザーがアプリで解除するまで表示）
        if state.state == .running, let endDate = state.endDate, endDate < Date() {
            return SharedTimerState(
                endDate: nil,
                totalDuration: state.totalDuration,
                state: .alarm
            )
        }

        return state
    }
}
