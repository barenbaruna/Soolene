//
//  CaptureButtonView.swift
//  Photograph
//
//  Shutter button with press-down animation and optional "perfect state" pulse.
//  When `isPerfect` is true, the button glows green and breathes to invite capture.
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

struct CaptureButton: View {
    let action: () -> Void
    var isPerfect: Bool = false

    @State private var isPressed = false
    @State private var glowPulsing = false

    var body: some View {
        Button(action: {
            withAnimation(.easeIn(duration: 0.05)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) { isPressed = false }
            }
            action()
        }) {
            ZStack {
                // Perfect state glow — green halo behind the button
                if isPerfect {
                    Circle()
                        .fill(AppColors.gridlineGreen.opacity(glowPulsing ? 0.4 : 0.15))
                        .frame(
                            width: ControlMetrics.shutterOuter + 16,
                            height: ControlMetrics.shutterOuter + 16
                        )
                        .blur(radius: 8)
                }

                // Outer ring
                Circle()
                    .fill(isPerfect
                        ? AppColors.gridlineGreen.opacity(0.6)
                        : Color(uiColor: .systemGray2)
                    )
                    .frame(width: ControlMetrics.shutterOuter, height: ControlMetrics.shutterOuter)

                // Inner filled circle with border
                ZStack {
                    Circle()
                        .fill(.white)
                    Circle()
                        .strokeBorder(
                            isPerfect ? AppColors.gridlineGreen : AppColors.primary,
                            lineWidth: 2
                        )
                }
                .frame(width: ControlMetrics.shutterInner, height: ControlMetrics.shutterInner)
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
            }
            .scaleEffect(isPerfect && glowPulsing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: glowPulsing)
        }
        .accessibilityLabel(isPerfect ? "Capture Photo — Perfect Composition" : "Capture Photo")
        .accessibilityHint("Takes a photo with the current composition overlay")
        .onChange(of: isPerfect) { _, newValue in
            glowPulsing = newValue
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 30) {
            CaptureButton(action: {}, isPerfect: false)
            CaptureButton(action: {}, isPerfect: true)
        }
    }
}
