//
//  RoutyraComplications.swift
//  RoutyraComplications
//
//  Created by 村田昌知 on 2026/01/23.
//

import SwiftUI
import WidgetKit

struct RoutyraComplications: Widget {
    let kind: String = SharedTimerStateManager.complicationKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationTimelineProvider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Routyra")
        .description("レストタイマーの進行状況を表示")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}
