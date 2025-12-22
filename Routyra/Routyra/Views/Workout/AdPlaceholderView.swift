//
//  AdPlaceholderView.swift
//  Routyra
//

import SwiftUI

struct AdPlaceholderView: View {
    var body: some View {
        HStack {
            Text("ad_sponsored")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.background)
                .cornerRadius(4)

            Rectangle()
                .fill(AppColors.divider)
                .frame(width: 1, height: 16)

            Text("ad_placeholder_title")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackgroundCompleted)
        .cornerRadius(8)
    }
}

#Preview {
    AdPlaceholderView()
        .padding()
        .background(AppColors.background)
        .preferredColorScheme(.dark)
}
