//
//  ActiveBadge.swift
//  Routyra
//
//  共通のActive状態バッジコンポーネント

import SwiftUI

/// Active状態を示すバッジ（プラン・サイクル共通）
struct ActiveBadge: View {
    var body: some View {
        Text(L10n.tr("active"))
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AppColors.accentBlue)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

#Preview {
    ActiveBadge()
        .padding()
        .background(AppColors.cardBackground)
        .preferredColorScheme(.dark)
}
