//
//  CameraTopRow.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Top area of the camera HUD, containing the settings button and guidance tip.
struct CameraTopRow: View {
    let viewModel: CameraViewModel
    let isCountingDown: Bool
    let iconRotation: Double
    let onSettingsTapped: () -> Void

    var body: some View {
        VStack(spacing: Spacing.small) {
            // Settings button — top-right
            HStack {
                Spacer()
                if !isCountingDown {
                    Button {
                        HapticManager.selection()
                        onSettingsTapped()
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(iconRotation))
                            .glassCircle(size: 40)
                    }
                    .accessibilityLabel("Camera Settings")
                }
            }

            // Guidance tip — centered, below the settings button
            if let technique = viewModel.activeTechnique, !isCountingDown {
                GuidanceTipView(tip: "Align the subject with the guidelines.")
            }
        }
    }
}
