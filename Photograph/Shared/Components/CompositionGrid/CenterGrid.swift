//
//  CenterGrid.swift
//  Photograph
//

import SwiftUI

struct CenterGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3
        let targetRadius = min(rect.width, rect.height) * 0.15

        ZStack {
            ForEach(1 ... 2, id: \.self) { i in
                GridLine(
                    start: CGPoint(x: rect.minX + thirdW * CGFloat(i), y: rect.minY),
                    end: CGPoint(x: rect.minX + thirdW * CGFloat(i), y: rect.maxY),
                    color: GridMetrics.guideMuted,
                    lineWidth: GridMetrics.secondary,
                    isDashed: false
                )
                GridLine(
                    start: CGPoint(x: rect.minX, y: rect.minY + thirdH * CGFloat(i)),
                    end: CGPoint(x: rect.maxX, y: rect.minY + thirdH * CGFloat(i)),
                    color: GridMetrics.guideMuted,
                    lineWidth: GridMetrics.secondary,
                    isDashed: false
                )
            }

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
