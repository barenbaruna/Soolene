//
//  DiagonalGrid.swift
//  Soolene
//

import SwiftUI

struct DiagonalGrid: View {
    let size: CGSize
    let color: Color
    let isPerfect: Bool

    var body: some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        ZStack {
            GridLine(
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                color: color,
                lineWidth: GridMetrics.primary,
                isDashed: false
            )
            GridLine(
                start: CGPoint(x: size.width, y: 0),
                end: CGPoint(x: 0, y: size.height),
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
