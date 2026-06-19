//
//  FrontCameraZoomToggle.swift
//  Photograph
//
//  Created by Baren Baruna Harahap.
//

import SwiftUI

struct FrontCameraZoomToggle: View {
    let isZoomedOut: Bool
    let iconRotation: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if #available(iOS 26, *) {
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.15)), in: .circle)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                }

                Image(systemName: isZoomedOut ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(iconRotation))
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .overlay(
                Circle().strokeBorder(AppColors.controlActive.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(ZoomToggleButtonStyle())
        .accessibilityLabel(isZoomedOut ? "Zoom In" : "Zoom Out")
        .accessibilityHint("Toggles the front camera zoom level")
    }
}

private struct ZoomToggleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
