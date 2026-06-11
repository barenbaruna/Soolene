//
//  CaptureButton.swift
//  Photograph
//
//  Shutter: white outer ring + olive inner fill (design reference).
//  Perfect state adds green glow and ring.
//

import SwiftUI

struct CaptureButton: View {
    let action: () -> Void
    var isPerfect: Bool = false
    var isDisabled: Bool = false

    @State private var isPressed = false
    @State private var glowPulsing = false

    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            withAnimation(.easeIn(duration: 0.05)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) { isPressed = false }
            }
            action()
        }) {
            ZStack {
                if isPerfect {
                    Circle()
                        .fill(AppColors.gridlineGreen.opacity(glowPulsing ? 0.35 : 0.12))
                        .frame(
                            width: ControlMetrics.shutterOuter + 20,
                            height: ControlMetrics.shutterOuter + 20
                        )
                        .blur(radius: 10)
                }

                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: ControlMetrics.shutterOuter, height: ControlMetrics.shutterOuter)

                Circle()
                    .fill(isPerfect ? AppColors.gridlineGreen : AppColors.primary)
                    .frame(width: ControlMetrics.shutterInner, height: ControlMetrics.shutterInner)
                    .scaleEffect(isPressed ? 0.88 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
            }
            .scaleEffect(isPerfect && glowPulsing ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: glowPulsing)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(isPerfect ? "Capture Photo — Perfect Composition" : "Capture Photo")
        .onChange(of: isPerfect) { _, newValue in
            glowPulsing = newValue
        }
    }
}
