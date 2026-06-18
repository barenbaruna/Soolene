//
//  VerticalGrid.swift
//  Photograph
//

import SwiftUI

struct VerticalGrid: View {
    let size: CGSize
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let leftThirdX = size.width * 0.33
        let rightThirdX = size.width * 0.67
        let centerX = size.width / 2
        let tickWidth: CGFloat = 16

        ZStack {
            GridLine(
                start: CGPoint(x: leftThirdX, y: 0),
                end: CGPoint(x: leftThirdX, y: size.height),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )
            GridLine(
                start: CGPoint(x: rightThirdX, y: 0),
                end: CGPoint(x: rightThirdX, y: size.height),
                color: GridMetrics.guideMuted,
                lineWidth: GridMetrics.secondary,
                isDashed: true
            )

            GridLine(
                start: CGPoint(x: centerX, y: 0),
                end: CGPoint(x: centerX, y: size.height),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )

            GridLine(
                start: CGPoint(x: centerX - tickWidth, y: size.height / 2),
                end: CGPoint(x: centerX + tickWidth, y: size.height / 2),
                color: color,
                lineWidth: GridMetrics.tick,
                isDashed: false
            )

            if isPerfect {
                GridLine(
                    start: CGPoint(x: centerX, y: 0),
                    end: CGPoint(x: centerX, y: size.height),
                    color: color,
                    lineWidth: GridMetrics.emphasis,
                    isDashed: false
                )
                .shadow(color: color, radius: 12)
            }
        }
    }
}
