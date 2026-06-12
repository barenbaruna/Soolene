//
//  CaptureButton.swift
//  Photograph
//
//  Shutter: olive (idle) → gold (stabilizing) → green (ready).
//

import SwiftUI

struct CaptureButton: View {
    let action: () -> Void
    var readiness: ShutterReadiness = .idle
    var isDisabled: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                if readiness == .ready {
                    Circle()
                        .fill(AppColors.gridlineGreen.opacity(glowPulsing ? 0.35 : 0.12))
                        .frame(
                            width: ControlMetrics.shutterOuter + 20,
                            height: ControlMetrics.shutterOuter + 20
                        )
                        .blur(radius: 10)
                } else if readiness == .stabilizing {
                    Circle()
                        .fill(AppColors.controlActive.opacity(glowPulsing ? 0.28 : 0.1))
                        .frame(
                            width: ControlMetrics.shutterOuter + 14,
                            height: ControlMetrics.shutterOuter + 14
                        )
                        .blur(radius: 8)
                }

                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: ControlMetrics.shutterOuter, height: ControlMetrics.shutterOuter)

                Circle()
                    .fill(innerFillColor)
                    .frame(width: ControlMetrics.shutterInner, height: ControlMetrics.shutterInner)
                    .scaleEffect(isPressed ? 0.88 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
            }
            .scaleEffect(pulseScale)
            .animation(pulseAnimation, value: glowPulsing)
        }
        .disabled(isDisabled)
        .opacity(buttonOpacity)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: readiness) { _, newValue in
            glowPulsing = newValue != .idle && !reduceMotion
        }
        .onAppear {
            glowPulsing = readiness != .idle && !reduceMotion
        }
    }

    private var innerFillColor: Color {
        switch readiness {
        case .ready: return AppColors.gridlineGreen
        case .stabilizing: return AppColors.controlActive
        case .idle: return AppColors.primary
        }
    }

    private var buttonOpacity: Double {
        if isDisabled && readiness == .idle { return 0.45 }
        return 1
    }

    private var pulseScale: CGFloat {
        guard !reduceMotion, glowPulsing else { return 1 }
        return readiness == .ready ? 1.04 : 1.02
    }

    private var pulseAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: readiness == .ready ? 0.8 : 1.1).repeatForever(autoreverses: true)
    }

    private var accessibilityLabel: String {
        switch readiness {
        case .ready: return "Capture Photo — ready"
        case .stabilizing: return "Capture Photo — hold steady, stabilizing"
        case .idle: return "Capture Photo"
        }
    }
}
