//
//  CameraTopRow.swift
//  Photograph
//
//  Top area of the camera HUD:
//  - Settings button (6-dot grid icon, top-right)
//  - Guidance tip label (fits text width, dark capsule)
//
//  HIG §15.1: .regularMaterial for pill backgrounds
//  HIG §2.2: .subheadline for secondary label
//
//  Uses Design System: Spacing, Typography.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct CameraTopRow: View {
    let viewModel: CameraViewModel
    let isCountingDown: Bool
    let iconRotation: Double
    let onSettingsTapped: () -> Void

    var body: some View {
        VStack(spacing: Spacing.standard) {
            // Settings button — top-right
            HStack {
                Spacer()
                if !isCountingDown {
                    Button {
                        HapticManager.selection()
                        onSettingsTapped()
                    } label: {
                        Image(systemName: "circle.grid.2x3.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(iconRotation))
                            .glassCircle(size: 40)
                    }
                    .accessibilityLabel("Camera Settings")
                }
            }

            // Guidance tip — fits text width, not full width
            if !isCountingDown {
                Text(guidanceTip(for: viewModel.compositionLabel))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small + 2)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .animation(.spring(response: 0.5), value: viewModel.compositionLabel)
            }
        }
    }

    private func guidanceTip(for label: String) -> String {
        switch label {
        case "Center":
            return "Place the main object on one of circle"
        case "Rule of Thirds":
            return "Place key elements at the intersections"
        case "Horizontal":
            return "Align elements along the horizontal lines"
        case "Vertical":
            return "Align elements along the vertical lines"
        case "Diagonal":
            return "Follow the diagonal lines for dynamic energy"
        default:
            return "Follow the on-screen guides"
        }
    }
}
