//
//  BottomStatusBarView.swift
//  Routyra
//

import SwiftUI

struct BottomStatusBarView: View {
    let sets: Int
    let exercises: Int
    let volume: Double

    private var formattedVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? "0"
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 0.5)

            HStack {
                StatItemView(label: "Sets", value: "\(sets)")
                Spacer()
                StatItemView(label: "Exercises", value: "\(exercises)")
                Spacer()
                StatItemView(label: "Total Volume", value: "\(formattedVolume) kg")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppColors.background)
        }
    }
}

struct StatItemView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

#Preview {
    BottomStatusBarView(sets: 8, exercises: 3, volume: 4320)
        .preferredColorScheme(.dark)
}
