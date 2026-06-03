//
//  CompositionOverlayView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI
import UIKit

/// Draws composition guide overlays using Core Graphics.
/// Only supports 5 compositions: Rule of Thirds, Center, Horizontal, Vertical, Diagonal.
struct CompositionOverlayView: UIViewRepresentable {
    let composition: CompositionType
    let geometry: SceneGeometry
    let aspectRatio: AspectRatioMode
    let subjectOffset: CGVector
    let isPerfect: Bool

    func makeUIView(context: Context) -> OverlayCanvas {
        let canvas = OverlayCanvas()
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.isUserInteractionEnabled = false
        return canvas
    }

    func updateUIView(_ canvas: OverlayCanvas, context: Context) {
        canvas.composition = composition
        canvas.geometry = geometry
        canvas.aspectRatio = aspectRatio
        canvas.subjectOffset = subjectOffset
        canvas.isPerfect = isPerfect
        canvas.setNeedsDisplay()
    }
}

// MARK: - Canvas (Core Graphics Drawing)

final class OverlayCanvas: UIView {
    var composition: CompositionType = .ruleOfThirds
    var geometry = SceneGeometry()
    var aspectRatio: AspectRatioMode = .free
    var subjectOffset: CGVector = .zero
    var isPerfect = false

    // MARK: - Colors

    private let guideColor = UIColor.white.withAlphaComponent(0.3)
    private let accentColor = UIColor.systemYellow.withAlphaComponent(0.8)
    private let perfectColor = UIColor.systemGreen.withAlphaComponent(0.9)

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        // Calculate drawing area based on aspect ratio
        let drawRect = aspectMaskedRect(in: rect)

        // Draw dim mask outside aspect ratio
        if aspectRatio != .free {
            drawAspectMask(ctx: ctx, full: rect, content: drawRect)
        }

        // Draw the appropriate guide
        switch composition {
        case .ruleOfThirds:
            drawRuleOfThirds(ctx: ctx, rect: drawRect)
        case .center:
            drawCenter(ctx: ctx, rect: drawRect)
        case .horizontal:
            drawHorizontal(ctx: ctx, rect: drawRect)
        case .vertical:
            drawVertical(ctx: ctx, rect: drawRect)
        case .diagonal:
            drawDiagonal(ctx: ctx, rect: drawRect)
        }

        // Draw subject indicator if available
        drawSubjectIndicator(ctx: ctx, rect: drawRect)
    }

    // MARK: - Rule of Thirds

    private func drawRuleOfThirds(ctx: CGContext, rect: CGRect) {
        ctx.setStrokeColor(guideColor.cgColor)
        ctx.setLineWidth(0.8)

        let thirdW = rect.width / 3
        let thirdH = rect.height / 3

        // Vertical lines
        for i in 1...2 {
            let x = rect.minX + thirdW * CGFloat(i)
            ctx.move(to: CGPoint(x: x, y: rect.minY))
            ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        // Horizontal lines
        for i in 1...2 {
            let y = rect.minY + thirdH * CGFloat(i)
            ctx.move(to: CGPoint(x: rect.minX, y: y))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        ctx.strokePath()

        // Highlight nearest power point to subject
        if let centroid = geometry.saliencyCentroid {
            let subjectPt = denormalize(centroid, in: rect)
            let closestX = centroid.x < 0.5
                ? rect.minX + thirdW
                : rect.minX + thirdW * 2
            let closestY = centroid.y < 0.5
                ? rect.minY + thirdH
                : rect.minY + thirdH * 2

            let highlightColor = isPerfect ? perfectColor : accentColor
            
            if isPerfect {
                ctx.setShadow(offset: .zero, blur: 8, color: highlightColor.cgColor)
            }
            ctx.setFillColor(highlightColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: closestX - 4, y: closestY - 4, width: 8, height: 8))
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            // Dashed line from subject to power point
            if !isPerfect {
                ctx.setStrokeColor(highlightColor.withAlphaComponent(0.4).cgColor)
                ctx.setLineWidth(1.0)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                ctx.move(to: subjectPt)
                ctx.addLine(to: CGPoint(x: closestX, y: closestY))
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
            }
        }
    }

    // MARK: - Center

    private func drawCenter(ctx: CGContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 30

        // Outer circle
        ctx.setStrokeColor(guideColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))

        // Crosshair
        let crossLen: CGFloat = 12
        ctx.move(to: CGPoint(x: center.x - crossLen, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + crossLen, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - crossLen))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + crossLen))
        ctx.strokePath()

        // Inner dot — color based on alignment
        let dotColor = isPerfect ? perfectColor : accentColor
        if isPerfect {
            ctx.setShadow(offset: .zero, blur: 8, color: dotColor.cgColor)
        }
        ctx.setFillColor(dotColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
    }

    // MARK: - Horizontal

    private func drawHorizontal(ctx: CGContext, rect: CGRect) {
        ctx.setStrokeColor(guideColor.cgColor)
        ctx.setLineWidth(0.8)

        // 3 horizontal guide lines
        for fraction in [0.33, 0.5, 0.67] as [CGFloat] {
            let y = rect.minY + rect.height * fraction
            ctx.move(to: CGPoint(x: rect.minX, y: y))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        ctx.strokePath()

        // Horizon level indicator
        let horizonY = rect.midY
        let color = abs(geometry.horizonAngle) < 2.0 ? perfectColor : accentColor
        ctx.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2.0)

        // Rotate around center by horizon angle
        let angle = CGFloat(geometry.horizonAngle) * .pi / 180
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: horizonY)
        ctx.rotate(by: angle)
        let halfW = rect.width * 0.3
        ctx.move(to: CGPoint(x: -halfW, y: 0))
        ctx.addLine(to: CGPoint(x: halfW, y: 0))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Vertical

    private func drawVertical(ctx: CGContext, rect: CGRect) {
        ctx.setStrokeColor(guideColor.cgColor)
        ctx.setLineWidth(0.8)

        // 3 vertical guide lines
        for fraction in [0.33, 0.5, 0.67] as [CGFloat] {
            let x = rect.minX + rect.width * fraction
            ctx.move(to: CGPoint(x: x, y: rect.minY))
            ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        ctx.strokePath()

        // Center vertical emphasis
        let centerX = rect.midX
        ctx.setStrokeColor(accentColor.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: centerX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: centerX, y: rect.maxY))
        ctx.strokePath()
    }

    // MARK: - Diagonal

    private func drawDiagonal(ctx: CGContext, rect: CGRect) {
        ctx.setStrokeColor(guideColor.cgColor)
        ctx.setLineWidth(0.8)

        // Main diagonals
        ctx.move(to: CGPoint(x: rect.minX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        ctx.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        ctx.strokePath()

        // Center X marker
        let center = CGPoint(x: rect.midX, y: rect.midY)
        ctx.setFillColor(accentColor.withAlphaComponent(0.5).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
    }

    // MARK: - Subject Indicator

    private func drawSubjectIndicator(ctx: CGContext, rect: CGRect) {
        // Draw face rectangle if detected
        if let faceNorm = geometry.faceRect {
            let faceRect = CGRect(
                x: rect.minX + faceNorm.origin.x * rect.width,
                y: rect.minY + faceNorm.origin.y * rect.height,
                width: faceNorm.width * rect.width,
                height: faceNorm.height * rect.height
            )
            let color = isPerfect ? perfectColor : UIColor.white
            ctx.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1.0)
            ctx.setLineDash(phase: 0, lengths: [5, 3])
            ctx.stroke(faceRect)
            ctx.setLineDash(phase: 0, lengths: [])
        }
    }

    // MARK: - Helpers

    /// Converts normalized (0-1) point to pixel coordinates within the rect.
    private func denormalize(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    /// Calculates the content rect based on aspect ratio.
    private func aspectMaskedRect(in rect: CGRect) -> CGRect {
        guard aspectRatio != .free else { return rect }

        let ratio: CGFloat
        switch aspectRatio {
        case .oneOne: ratio = 1.0
        case .fourThree: ratio = 3.0 / 4.0
        case .sixteenNine: ratio = 9.0 / 16.0
        case .free: return rect
        }

        let maxW = rect.width
        let maxH = rect.height
        var w = maxW
        var h = w / ratio

        if h > maxH {
            h = maxH
            w = h * ratio
        }

        return CGRect(
            x: rect.midX - w / 2,
            y: rect.midY - h / 2,
            width: w,
            height: h
        )
    }

    /// Draws a semi-transparent mask outside the content area.
    private func drawAspectMask(ctx: CGContext, full: CGRect, content: CGRect) {
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)

        // Top bar
        ctx.fill(CGRect(x: full.minX, y: full.minY, width: full.width, height: content.minY - full.minY))
        // Bottom bar
        ctx.fill(CGRect(x: full.minX, y: content.maxY, width: full.width, height: full.maxY - content.maxY))
        // Left bar
        ctx.fill(CGRect(x: full.minX, y: content.minY, width: content.minX - full.minX, height: content.height))
        // Right bar
        ctx.fill(CGRect(x: content.maxX, y: content.minY, width: full.maxX - content.maxX, height: content.height))
    }
}
