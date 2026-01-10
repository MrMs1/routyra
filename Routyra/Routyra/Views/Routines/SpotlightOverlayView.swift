//
//  SpotlightOverlayView.swift
//  Routyra
//
//  Spotlight overlay that highlights a specific UI element.
//  Used to guide users to important actions after onboarding.
//

import SwiftUI

struct SpotlightOverlayView: View {
    let targetFrame: CGRect
    let label: String
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let localFrame = geometry.frame(in: .global)
            let adjustedFrame = CGRect(
                x: targetFrame.minX - localFrame.minX,
                y: targetFrame.minY - localFrame.minY,
                width: targetFrame.width,
                height: targetFrame.height
            )

            // ラベル位置：上部に十分なスペースがあれば上、なければ下に表示
            let labelHeight: CGFloat = 40
            let topSpace = adjustedFrame.minY - geometry.safeAreaInsets.top
            let showLabelAbove = topSpace > (labelHeight + 20)
            let labelY = showLabelAbove
                ? adjustedFrame.minY - labelHeight
                : adjustedFrame.maxY + labelHeight

            ZStack {
                // Dark overlay with cutout
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .mask(
                        Rectangle()
                            .fill(.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(
                                        width: adjustedFrame.width + 8,
                                        height: adjustedFrame.height + 8
                                    )
                                    .position(
                                        x: adjustedFrame.midX,
                                        y: adjustedFrame.midY
                                    )
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                // Highlight border around target
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.accentBlue, lineWidth: 2)
                    .frame(
                        width: adjustedFrame.width + 8,
                        height: adjustedFrame.height + 8
                    )
                    .position(
                        x: adjustedFrame.midX,
                        y: adjustedFrame.midY
                    )

                // Label (positioned above or below target)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.accentBlue)
                    .cornerRadius(8)
                    .position(
                        x: adjustedFrame.midX,
                        y: labelY
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()

        VStack {
            Spacer()
            Text("Sample Button")
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)
            Spacer()
        }

        SpotlightOverlayView(
            targetFrame: CGRect(x: 100, y: 400, width: 200, height: 60),
            label: "ここから作成できます",
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}
