//
//  Routyra_Watch_AppApp.swift
//  Routyra Watch App Watch App
//
//  Created by 村田昌知 on 2026/01/06.
//

import SwiftUI
import UserNotifications

@main
struct Routyra_Watch_App_Watch_AppApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    init() {
        // Set up notification categories (before delegate)
        WatchRestTimerManager.shared.setupNotificationCategories()
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = WatchRestTimerManager.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(connectivityManager)
                .onAppear {
                    WatchRestTimerManager.shared.requestNotificationPermissionIfNeeded()
                }
        }
    }
}
