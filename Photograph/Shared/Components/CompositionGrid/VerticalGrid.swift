//
//  VerticalGrid.swift
//  Photograph
//

import SwiftUI

struct VerticalGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let leftThirdX = rect.minX + rect.width * 0.33
        let rightThirdX = rect.minX + rect.width * 0.67
        let centerX = rect.midX
        let tickWidth: CGFloat = 16

        ZStack {
            GridLine(
                start: CGPoint(x: leftThirdX, y: rect.minY),
                end: CGPoint(x: leftThirdX, y: rect.maxY),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )
            GridLine(
                start: CGPoint(x: rightThirdX, y: rect.minY),
                end: CGPoint(x: rightThirdX, y: rect.maxY),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )

            GridLine(
                start: CGPoint(x: centerX, y: rect.minY),
                end: CGPoint(x: centerX, y: rect.maxY),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )

            GridLine(
                start: CGPoint(x: centerX - tickWidth, y: rect.midY),
                end: CGPoint(x: centerX + tickWidth, y: rect.midY),
                color: color,
                lineWidth: GridMetrics.tick,
                isDashed: false
            )

            if isPerfect {
                GridLine(
                    start: CGPoint(x: centerX, y: rect.minY),
                    end: CGPoint(x: centerX, y: rect.maxY),
                    color: color,
                    lineWidth: GridMetrics.emphasis,
                    isDashed: false
                )
                .shadow(color: color, radius: 12)
            }
        }
    }
}
