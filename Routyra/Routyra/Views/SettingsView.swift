//
//  SettingsView.swift
//  Routyra
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var profile: LocalProfile?

    var body: some View {
        List {
            // Workout Settings Section
            Section {
                dayTransitionPicker
            } header: {
                Text("ワークアウト")
            } footer: {
                Text("設定した時刻以降にアプリを起動すると、次の日のワークアウトメニューが表示されます。")
            }

            // App Info Section
            Section {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(AppColors.textSecondary)
                }
            } header: {
                Text("アプリ情報")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfile()
        }
    }

    // MARK: - Day Transition Picker

    private var dayTransitionPicker: some View {
        Picker("日付切り替え時刻", selection: Binding(
            get: { profile?.dayTransitionHour ?? 3 },
            set: { newValue in
                profile?.dayTransitionHour = newValue
                try? modelContext.save()
            }
        )) {
            ForEach(0..<24, id: \.self) { hour in
                Text(formatHour(hour))
                    .tag(hour)
            }
        }
    }

    // MARK: - Helpers

    private func loadProfile() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:00"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [LocalProfile.self], inMemory: true)
    .preferredColorScheme(.dark)
}
