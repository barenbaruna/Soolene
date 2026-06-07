//
//  StaticOverlayView.swift
//  Photograph
//
//  Draws composition guide lines on saved photos in the gallery.
//  Visual style matches the live camera overlay for consistency:
//  - Semi-transparent white lines with 1.5pt width
//  - Intersection circles with crosshairs (Rule of Thirds)
//  - Center crosshair circle (Center)
//  - Clean diagonal lines (Diagonal)
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws static composition guideline overlays on saved gallery photos.
/// Styled to match the live camera `CompositionOverlayView` for visual consistency.
struct StaticOverlayView: View {
    let composition: CompositionType
    let size: CGSize

    private let lineColor = Color.white.opacity(0.6)
    private let lineWidth: CGFloat = 1.5
    private let accentColor = Color.white.opacity(0.8)

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)

            switch composition {
            case .ruleOfThirds: drawRuleOfThirds(context: &context, rect: rect)
            case .center:       drawCenter(context: &context, rect: rect)
            case .horizontal:   drawHorizontal(context: &context, rect: rect)
            case .vertical:     drawVertical(context: &context, rect: rect)
            case .diagonal:     drawDiagonal(context: &context, rect: rect)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Rule of Thirds

    private func drawRuleOfThirds(context: inout GraphicsContext, rect: CGRect) {
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3

        // Grid lines
        for i in 1...2 {
            drawLine(&context, from: CGPoint(x: thirdW * CGFloat(i), y: 0),
                     to: CGPoint(x: thirdW * CGFloat(i), y: rect.height))
            drawLine(&context, from: CGPoint(x: 0, y: thirdH * CGFloat(i)),
                     to: CGPoint(x: rect.width, y: thirdH * CGFloat(i)))
        }

        // Intersection circles with crosshairs (matches camera grid)
        for col in 1...2 {
            for row in 1...2 {
                let center = CGPoint(x: thirdW * CGFloat(col), y: thirdH * CGFloat(row))
                let radius: CGFloat = 10

                // Circle
                let circleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                        width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: circleRect), with: .color(accentColor), lineWidth: 1.5)

                // Crosshair inside
                let armLen: CGFloat = radius * 0.6
                drawLine(&context, from: CGPoint(x: center.x - armLen, y: center.y),
                         to: CGPoint(x: center.x + armLen, y: center.y), width: 1.0, color: accentColor)
                drawLine(&context, from: CGPoint(x: center.x, y: center.y - armLen),
                         to: CGPoint(x: center.x, y: center.y + armLen), width: 1.0, color: accentColor)
            }
        }
    }

    // MARK: - Center

    private func drawCenter(context: inout GraphicsContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 30

        // Outer circle
        let circleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: circleRect), with: .color(accentColor), lineWidth: 1.5)

        // Inner crosshair
        let crossLen: CGFloat = 14
        drawLine(&context, from: CGPoint(x: center.x - crossLen, y: center.y),
                 to: CGPoint(x: center.x + crossLen, y: center.y), width: 1.0, color: accentColor)
        drawLine(&context, from: CGPoint(x: center.x, y: center.y - crossLen),
                 to: CGPoint(x: center.x, y: center.y + crossLen), width: 1.0, color: accentColor)

        // Center dot
        let dotSize: CGFloat = 4
        context.fill(Path(ellipseIn: CGRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2,
                                            width: dotSize, height: dotSize)),
                     with: .color(accentColor))
    }

    // MARK: - Horizontal

    private func drawHorizontal(context: inout GraphicsContext, rect: CGRect) {
        for fraction in [1.0 / 3.0, 0.5, 2.0 / 3.0] as [CGFloat] {
            let y = rect.height * fraction
            drawLine(&context, from: CGPoint(x: 0, y: y), to: CGPoint(x: rect.width, y: y))
        }
    }

    // MARK: - Vertical

    private func drawVertical(context: inout GraphicsContext, rect: CGRect) {
        for fraction in [1.0 / 3.0, 0.5, 2.0 / 3.0] as [CGFloat] {
            let x = rect.width * fraction
            drawLine(&context, from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: rect.height))
        }
    }

    // MARK: - Diagonal

    private func drawDiagonal(context: inout GraphicsContext, rect: CGRect) {
        drawLine(&context, from: .zero, to: CGPoint(x: rect.width, y: rect.height))
        drawLine(&context, from: CGPoint(x: rect.width, y: 0), to: CGPoint(x: 0, y: rect.height))
    }

    // MARK: - Drawing Helpers

    private func drawLine(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint,
                          width: CGFloat? = nil, color: Color? = nil) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color ?? lineColor), lineWidth: width ?? lineWidth)
    }
}
