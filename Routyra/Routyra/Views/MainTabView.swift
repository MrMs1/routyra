//
//  MainTabView.swift
//  Routyra
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var navigateToHistory = false
    @State private var navigateToRoutines = false

    // OPTIMIZATION: Track which tabs have been visited for lazy loading
    // WorkoutView (tab 0) is always loaded immediately as the primary screen
    @State private var loadedTabs: Set<Int> = [0]

    // Theme observation - forces view refresh when theme changes
    @State private var themeRefreshId = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: WorkoutView - Always loaded immediately (primary screen)
            WorkoutView(navigateToHistory: $navigateToHistory, navigateToRoutines: $navigateToRoutines)
                .tabItem {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("workout")
                }
                .tag(0)

            // Tab 1: HistoryView - Lazy loaded on first visit
            LazyTabContent(tab: 1, loadedTabs: $loadedTabs) {
                HistoryView()
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("history")
            }
            .tag(1)

            // Tab 2: RoutinesView - Lazy loaded on first visit
            LazyTabContent(tab: 2, loadedTabs: $loadedTabs) {
                RoutinesView()
            }
            .tabItem {
                Image(systemName: "list.bullet.rectangle")
                Text("routines")
            }
            .tag(2)

            // Tab 3: SettingsView - Lazy loaded on first visit
            LazyTabContent(tab: 3, loadedTabs: $loadedTabs) {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("settings")
            }
            .tag(3)
        }
        .tint(
            ThemeManager.shared.currentThemeType.prefersTabTextTint
                ? AppColors.textPrimary
                : AppColors.accentBlue
        )
        .onChange(of: selectedTab) { _, newTab in
            // Mark tab as loaded when first visited
            loadedTabs.insert(newTab)
        }
        .onChange(of: navigateToHistory) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation {
                    selectedTab = 1
                }
                navigateToHistory = false
            }
        }
        .onChange(of: navigateToRoutines) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation {
                    selectedTab = 2
                }
                navigateToRoutines = false
            }
        }
        .onAppear {
            syncThemeFromProfile()
        }
        .id(themeRefreshId)
        .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
            themeRefreshId = UUID()
        }
        .preferredColorScheme(ThemeManager.shared.currentThemeType.colorScheme)
    }

    // MARK: - Theme Sync

    private func syncThemeFromProfile() {
        let profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        ThemeManager.shared.sync(with: profile.themeType)
    }
}

// MARK: - Lazy Tab Content

/// Helper view for lazy loading tab content
/// Only initializes the content when the tab is first visited
private struct LazyTabContent<Content: View>: View {
    let tab: Int
    @Binding var loadedTabs: Set<Int>
    @ViewBuilder let content: () -> Content

    var body: some View {
        if loadedTabs.contains(tab) {
            content()
        } else {
            // Placeholder until tab is selected - uses app background color
            Color(AppColors.background)
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
