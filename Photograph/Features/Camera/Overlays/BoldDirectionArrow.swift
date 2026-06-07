//
//  BoldDirectionArrow.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// A full-screen Canvas that draws a solid directional arrow
/// from the current subject position to the ideal target position.
///
/// Design decisions:
/// - Solid line (not dashed) — easier to follow direction at a glance
/// - 3pt shaft, filled triangular arrowhead
/// - Line stops slightly before the arrowhead tip for visual clarity
struct BoldDirectionArrow: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let opacity: Double

    var body: some View {
        Canvas { ctx, _ in
            guard hypot(to.x - from.x, to.y - from.y) > 20 else { return }

            let angle = atan2(to.y - from.y, to.x - from.x)
            let arrowLength: CGFloat = 22
            let arrowAngle: CGFloat = .pi / 5 // 36 degrees -> wide, clearly visible arrowhead

            // The line ends slightly before the tip so it doesn't overlap the arrowhead
            let shaftEnd = CGPoint(
                x: to.x - arrowLength * 0.6 * cos(angle),
                y: to.y - arrowLength * 0.6 * sin(angle)
            )

            // Shaft
            var shaft = Path()
            shaft.move(to: from)
            shaft.addLine(to: shaftEnd)
            ctx.stroke(
                shaft,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

            // Arrowhead (filled triangle)
            var head = Path()
            head.move(to: to)
            head.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle - arrowAngle),
                y: to.y - arrowLength * sin(angle - arrowAngle)
            ))
            head.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle + arrowAngle),
                y: to.y - arrowLength * sin(angle + arrowAngle)
            ))
            head.closeSubpath()
            ctx.fill(head, with: .color(color.opacity(opacity)))
        }
    }
}
