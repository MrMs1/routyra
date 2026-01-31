//
//  ComplicationTimelineProvider.swift
//  RoutyraComplications
//
//  Timeline provider for watch complications.
//

import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let timerState: SharedTimerState
}

struct ComplicationTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), timerState: .defaultState)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let state = SharedTimerStateManager.load()
        completion(ComplicationEntry(date: Date(), timerState: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let state = SharedTimerStateManager.load()
        let now = Date()

        switch state.state {
        case .running:
            if let endDate = state.endDate, endDate > now {
                // Running now, alarm at endDate regardless of external state refresh.
                let runningEntry = ComplicationEntry(date: now, timerState: state)
                let alarmEntry = ComplicationEntry(
                    date: endDate,
                    timerState: SharedTimerState(endDate: nil, totalDuration: state.totalDuration, state: .alarm)
                )
                let timeline = Timeline(entries: [runningEntry, alarmEntry], policy: .never)
                completion(timeline)
                return
            }
            let entry = ComplicationEntry(date: now, timerState: state)
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
            return
        case .idle, .alarm:
            let entry = ComplicationEntry(date: now, timerState: state)
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
            return
        }
    }
}
