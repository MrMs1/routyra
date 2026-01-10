//
//  BottomStatusBarView.swift
//  Routyra
//

import SwiftUI

struct BottomStatusBarView: View {
    let sets: Int
    let exercises: Int
    let volume: Double
    var weightUnit: WeightUnit = .kg

    private var labelColor: Color { AppColors.textMuted }
    private var unitColor: Color { AppColors.textSecondary }

    private var formattedVolume: String {
        Formatters.decimal0.string(from: NSNumber(value: volume)) ?? "0"
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
                unit: weightUnit.symbol,
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
    var labelColor: Color = AppColors.textMuted

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
