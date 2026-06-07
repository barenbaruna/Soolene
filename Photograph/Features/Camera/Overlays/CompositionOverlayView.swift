//
//  CompositionOverlayView.swift
//  Photograph
//
//  Draws live composition guide lines on the camera preview.
//  Supports all 5 composition types: Rule of Thirds, Center, Horizontal, Vertical, Diagonal.
//
//  Line colors adapt to alignment state:
//  - Red (AppColors.gridlineRed)   → scene is NOT aligned
//  - Green (AppColors.gridlineGreen) → scene IS aligned
//
//  Uses Design System tokens: AppColors (gridlineRed, gridlineGreen).
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

struct CompositionOverlayView: View {
    let composition: CompositionType
    let isAligned: Bool

    /// Line color adapts to alignment state.
    private var lineColor: Color {
        isAligned ? AppColors.gridlineGreen : AppColors.gridlineRed
    }

    private let lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)

                switch composition {
                case .ruleOfThirds: drawRuleOfThirds(in: &context, rect: rect)
                case .center:       drawCenter(in: &context, rect: rect)
                case .horizontal:   drawHorizontal(in: &context, rect: rect)
                case .vertical:     drawVertical(in: &context, rect: rect)
                case .diagonal:     drawDiagonal(in: &context, rect: rect)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Rule of Thirds

    private func drawRuleOfThirds(in context: inout GraphicsContext, rect: CGRect) {
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3

        // Grid lines
        for i in 1...2 {
            drawLine(&context, from: CGPoint(x: thirdW * CGFloat(i), y: 0),
                     to: CGPoint(x: thirdW * CGFloat(i), y: rect.height))
            drawLine(&context, from: CGPoint(x: 0, y: thirdH * CGFloat(i)),
                     to: CGPoint(x: rect.width, y: thirdH * CGFloat(i)))
        }

        // Intersection circles with crosshairs
        for col in 1...2 {
            for row in 1...2 {
                let center = CGPoint(x: thirdW * CGFloat(col), y: thirdH * CGFloat(row))
                drawCrosshairCircle(&context, center: center, radius: 12)
            }
        }
    }

    // MARK: - Center

    private func drawCenter(in context: inout GraphicsContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Full-width horizontal + vertical crosshair lines
        drawLine(&context, from: CGPoint(x: 0, y: center.y), to: CGPoint(x: rect.width, y: center.y))
        drawLine(&context, from: CGPoint(x: center.x, y: 0), to: CGPoint(x: center.x, y: rect.height))

        // Center target circle
        drawCrosshairCircle(&context, center: center, radius: 30)
    }

    // MARK: - Horizontal

    private func drawHorizontal(in context: inout GraphicsContext, rect: CGRect) {
        for fraction in [1.0 / 3.0, 0.5, 2.0 / 3.0] as [CGFloat] {
            let y = rect.height * fraction
            drawLine(&context, from: CGPoint(x: 0, y: y), to: CGPoint(x: rect.width, y: y))
        }
    }

    // MARK: - Vertical

    private func drawVertical(in context: inout GraphicsContext, rect: CGRect) {
        for fraction in [1.0 / 3.0, 0.5, 2.0 / 3.0] as [CGFloat] {
            let x = rect.width * fraction
            drawLine(&context, from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: rect.height))
        }
    }

    // MARK: - Diagonal

    private func drawDiagonal(in context: inout GraphicsContext, rect: CGRect) {
        drawLine(&context, from: .zero, to: CGPoint(x: rect.width, y: rect.height))
        drawLine(&context, from: CGPoint(x: rect.width, y: 0), to: CGPoint(x: 0, y: rect.height))
    }

    // MARK: - Drawing Helpers

    private func drawLine(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
    }

    private func drawCrosshairCircle(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Circle outline
        let circleRect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        context.stroke(Path(ellipseIn: circleRect), with: .color(lineColor), lineWidth: lineWidth)

        // Internal crosshair arms
        let armLen = radius * 0.5
        var hPath = Path()
        hPath.move(to: CGPoint(x: center.x - armLen, y: center.y))
        hPath.addLine(to: CGPoint(x: center.x + armLen, y: center.y))
        context.stroke(hPath, with: .color(lineColor), lineWidth: 1)

        var vPath = Path()
        vPath.move(to: CGPoint(x: center.x, y: center.y - armLen))
        vPath.addLine(to: CGPoint(x: center.x, y: center.y + armLen))
        context.stroke(vPath, with: .color(lineColor), lineWidth: 1)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CompositionOverlayView(composition: .center, isAligned: false)
    }
}
