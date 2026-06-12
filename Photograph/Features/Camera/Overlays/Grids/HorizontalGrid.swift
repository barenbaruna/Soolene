//
//  HorizontalGrid.swift
//  Photograph
//

import SwiftUI

struct HorizontalGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let topThirdY = rect.minY + rect.height * 0.33
        let bottomThirdY = rect.minY + rect.height * 0.67
        let centerY = rect.midY
        let tickHeight: CGFloat = 16

        ZStack {
            GridLine(
                start: CGPoint(x: rect.minX, y: topThirdY),
                end: CGPoint(x: rect.maxX, y: topThirdY),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )
            GridLine(
                start: CGPoint(x: rect.minX, y: bottomThirdY),
                end: CGPoint(x: rect.maxX, y: bottomThirdY),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )

            GridLine(
                start: CGPoint(x: rect.minX, y: centerY),
                end: CGPoint(x: rect.maxX, y: centerY),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )

            GridLine(
                start: CGPoint(x: rect.midX, y: centerY - tickHeight),
                end: CGPoint(x: rect.midX, y: centerY + tickHeight),
                color: color,
                lineWidth: GridMetrics.tick,
                isDashed: false
            )

            if isPerfect {
                GridLine(
                    start: CGPoint(x: rect.minX, y: centerY),
                    end: CGPoint(x: rect.maxX, y: centerY),
                    color: color,
                    lineWidth: GridMetrics.emphasis,
                    isDashed: false
                )
                .shadow(color: color, radius: 12)
            }
        }
    }
}
