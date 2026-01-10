//
//  Routyra_Watch_AppApp.swift
//  Routyra Watch App Watch App
//
//  Created by 村田昌知 on 2026/01/06.
//

import SwiftUI

@main
struct Routyra_Watch_App_Watch_AppApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(connectivityManager)
        }
    }
}
