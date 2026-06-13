//
//  DiagonalGrid.swift
//  Photograph
//

import SwiftUI

struct DiagonalGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        ZStack {
            GridLine(
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )
            GridLine(
                start: CGPoint(x: rect.maxX, y: rect.minY),
                end: CGPoint(x: rect.minX, y: rect.maxY),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )

            Crosshair(
                center: center,
                armLength: 18,
                color: color,
                lineWidth: GridMetrics.crosshair
            )

            if isPerfect {
                Crosshair(center: center, armLength: 18, color: color, lineWidth: GridMetrics.emphasis)
                    .shadow(color: color, radius: 12)
            }
        }
    }
}
