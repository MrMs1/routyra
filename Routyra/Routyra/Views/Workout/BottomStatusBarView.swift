//
//  BottomStatusBarView.swift
//  Routyra
//

import SwiftUI

struct BottomStatusBarView: View {
    let sets: Int
    let exercises: Int
    let volume: Double

    private let labelColor = Color.white.opacity(0.42)
    private let unitColor = Color.white.opacity(0.62)

    private var formattedVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? "0"
    }

    var body: some View {
        HStack {
            StatItemView(label: L10n.tr("bottom_status_sets"), value: "\(sets)", labelColor: labelColor)
            Spacer()
            StatItemView(label: L10n.tr("bottom_status_exercises"), value: "\(exercises)", labelColor: labelColor)
            Spacer()
            VolumeStatItemView(
                label: L10n.tr("bottom_status_total_volume"),
                value: formattedVolume,
                unit: L10n.tr("unit_kg"),
                labelColor: labelColor,
                unitColor: unitColor
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.divider.opacity(0.6), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct StatItemView: View {
    let label: String
    let value: String
    var labelColor: Color = Color.white.opacity(0.42)

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(labelColor)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

struct VolumeStatItemView: View {
    let label: String
    let value: String
    let unit: String
    var labelColor: Color
    var unitColor: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(labelColor)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text(unit)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(unitColor)
            }
        }
    }
}

#Preview {
    BottomStatusBarView(sets: 8, exercises: 3, volume: 4320)
        .preferredColorScheme(.dark)
}
