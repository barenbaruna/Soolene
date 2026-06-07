//
//  PulsingTargetRing.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// An animated circle ring that pulses outward continuously.
/// Draws attention to the IDEAL position for the subject.
///
/// - Outer ring: fades out as it scales up (pulse effect)
/// - Inner ring: solid, always visible
/// - Center dot: indicates exact target point
struct PulsingTargetRing: View {
    let color: Color
    let isPerfect: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring — scales 1.0 -> 1.6 and fades out
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)
                .animation(
                    .easeOut(duration: 1.3).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // Inner ring — always visible
            Circle()
                .stroke(color, lineWidth: 2.5)

            // Center dot
            Circle()
                .fill(color)
                .frame(width: isPerfect ? 12 : 8, height: isPerfect ? 12 : 8)
                .animation(.spring(response: 0.3), value: isPerfect)

            // Success glow when perfect
            if isPerfect {
                Circle()
                    .fill(color.opacity(0.25))
                    .scaleEffect(1.2)
            }
        }
        .onAppear { isPulsing = true }
    }
}
