//
//  MainTabView.swift
//  Routyra
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var navigateToHistory = false

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutView(navigateToHistory: $navigateToHistory)
                .tabItem {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("Workout")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("History")
                }
                .tag(1)

            RoutinesView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Routines")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(AppColors.accentBlue)
        .onChange(of: navigateToHistory) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation {
                    selectedTab = 1
                }
                navigateToHistory = false
            }
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
