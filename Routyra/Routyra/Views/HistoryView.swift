//
//  HistoryView.swift
//  Routyra
//

import SwiftUI

struct HistoryView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("history")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("history_subtitle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
