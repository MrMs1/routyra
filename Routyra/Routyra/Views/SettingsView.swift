//
//  SettingsView.swift
//  Routyra
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("App configuration and preferences")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
