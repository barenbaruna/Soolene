//
//  CameraTopRow.swift
//  Photograph
//
//  Top area of the camera HUD:
//  - Settings button (6-dot grid icon, top-right)
//  - Phase-aware guidance tip (icon + text + contextual color)
//
//  HIG §15.1: .regularMaterial for pill backgrounds
//  HIG §2.2: .subheadline for secondary label
//
//  Uses Design System: Spacing, Typography, GuidanceTipView.
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
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(iconRotation))
                            .frame(width: ControlMetrics.settingsButton, height: ControlMetrics.settingsButton)
                            .background(.black.opacity(0.46), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Camera Settings")
                }
            }

            // Phase-aware guidance tip
            if !isCountingDown {
                GuidanceTipView(
                    phase: viewModel.guidancePhase,
                    tip: viewModel.guidanceTip,
                    composition: viewModel.userSelectedComposition
                )
            }
        }
    }
}
