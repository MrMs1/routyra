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
                Text("History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Weekly and monthly workout history")
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
