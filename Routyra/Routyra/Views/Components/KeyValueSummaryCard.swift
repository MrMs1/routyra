//
//  KeyValueSummaryCard.swift
//  Routyra
//
//  Reusable card UI for displaying label/value rows.
//

import SwiftUI

struct KeyValueSummaryCard: View {
    struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows) { row in
                HStack {
                    Text(row.label)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text(row.value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }
}

