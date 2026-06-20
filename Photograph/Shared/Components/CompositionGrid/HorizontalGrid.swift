//
//  HorizontalGrid.swift
//  Soolene
//

import SwiftUI

struct HorizontalGrid: View {
    let size: CGSize
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let topThirdY = size.height * 0.33
        let bottomThirdY = size.height * 0.67
        let centerY = size.height / 2
        let tickHeight: CGFloat = 16

        ZStack {
            GridLine(
                start: CGPoint(x: 0, y: topThirdY),
                end: CGPoint(x: size.width, y: topThirdY),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )
            GridLine(
                start: CGPoint(x: 0, y: bottomThirdY),
                end: CGPoint(x: size.width, y: bottomThirdY),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )

            GridLine(
                start: CGPoint(x: 0, y: centerY),
                end: CGPoint(x: size.width, y: centerY),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )

            GridLine(
                start: CGPoint(x: size.width / 2, y: centerY - tickHeight),
                end: CGPoint(x: size.width / 2, y: centerY + tickHeight),
                color: color,
                lineWidth: GridMetrics.tick,
                isDashed: false
            )

            if isPerfect {
                GridLine(
                    start: CGPoint(x: 0, y: centerY),
                    end: CGPoint(x: size.width, y: centerY),
                    color: color,
                    lineWidth: GridMetrics.emphasis,
                    isDashed: false
                )
                .shadow(color: color, radius: 12)
            }
        }
    }
}
