//
//  CenterGrid.swift
//  Photograph
//

import SwiftUI

struct CenterGrid: View {
    let size: CGSize
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let targetRadius = min(size.width, size.height) * 0.15

        ZStack {
            TargetCircle(
                center: center,
                radius: targetRadius,
                color: color,
                lineWidth: GridMetrics.targetRing
            )

            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .position(center)
                .shadow(color: .black.opacity(0.35), radius: 1)

            Crosshair(
                center: center,
                armLength: targetRadius + 16,
                color: color,
                lineWidth: isPerfect ? GridMetrics.crosshair : GridMetrics.secondary
            )

            if isPerfect {
                TargetCircle(
                    center: center,
                    radius: targetRadius,
                    color: color,
                    lineWidth: GridMetrics.targetRingEmphasis
                )
                .shadow(color: color, radius: 16)
            }
        }
    }
}
