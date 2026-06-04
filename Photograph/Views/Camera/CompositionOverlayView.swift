//
//  CompositionOverlayView.swift
//  Photograph
//
//  Draws composition guide overlays using Core Graphics.
//
//  ─────────────────────────────────────────────────────────────────────
//  Color Logic (driven by CompositionAnalysis.sceneAlignmentScore):
//
//    score == 0.0       → WHITE lines  (no Vision data available yet)
//    score 0.0 – 0.8    → RED lines    (#D94A3D) — guide the user
//    score > 0.8        → GREEN lines  (#35C75A) — scene is aligned ✅
//
//  This logic is entirely based on SCENE/OBJECT detection from Vision,
//  NOT device gyroscope or physical orientation.
//  ─────────────────────────────────────────────────────────────────────
//
//  Line weights (from reference design):
//    - Primary guide lines: 1.5pt
//    - Highlighted/active lines: 2.5pt
//    - Dashed arrows / direction helpers: 1.0pt
//
//  Atomic Design hierarchy (within this file):
//    Atoms:      individual drawing functions (lines, circles, crosses)
//    Molecules:  per-composition drawing (ruleOfThirds, center, etc.)
//    Organism:   OverlayCanvas — orchestrates everything
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI
import UIKit

// MARK: - CompositionOverlayView (SwiftUI wrapper)

/// SwiftUI wrapper around OverlayCanvas (UIView).
/// Pass in the current CompositionAnalysis and it renders the correct overlay.
struct CompositionOverlayView: UIViewRepresentable {
    let composition: CompositionType
    let geometry: SceneGeometry
    let aspectRatio: AspectRatioMode
    let subjectOffset: CGVector
    let isPerfect: Bool
    let sceneAlignmentScore: Float
    let hasSceneData: Bool

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
        canvas.sceneAlignmentScore = sceneAlignmentScore
        canvas.hasSceneData = hasSceneData
        canvas.setNeedsDisplay()
    }
}

// MARK: - OverlayCanvas (Core Graphics drawing — UIView)

final class OverlayCanvas: UIView {

    // MARK: - Input Properties

    var composition: CompositionType = .ruleOfThirds
    var geometry = SceneGeometry()
    var aspectRatio: AspectRatioMode = .free
    var subjectOffset: CGVector = .zero
    var isPerfect = false
    var sceneAlignmentScore: Float = 0
    var hasSceneData: Bool = false

    // MARK: - Color Selection

    /// Returns the current guide color based on scene alignment score.
    ///
    /// - White:  No Vision data yet (score == 0.0)
    /// - Red:    Vision data present, composition not yet aligned (score < 0.8)
    /// - Green:  Vision data present, composition is aligned (score >= 0.8)
    private var guideColor: UIColor {
        if !hasSceneData { return .gridlineWhite }
        return sceneAlignmentScore >= 0.8 ? .gridlineGreen : .gridlineRed
    }

    /// A subtle white used for the secondary grid lines (always white,
    /// just dimmer — these are reference lines, not feedback lines).
    private let secondaryLineColor = UIColor.white.withAlphaComponent(0.25)

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let drawRect = aspectMaskedRect(in: rect)

        // Dim area outside the chosen aspect ratio
        if aspectRatio != .free {
            drawAspectMask(ctx: ctx, full: rect, content: drawRect)
        }

        // Draw the per-composition guide
        switch composition {
        case .ruleOfThirds: drawRuleOfThirds(ctx: ctx, rect: drawRect)
        case .center:       drawCenter(ctx: ctx, rect: drawRect)
        case .horizontal:   drawHorizontal(ctx: ctx, rect: drawRect)
        case .vertical:     drawVertical(ctx: ctx, rect: drawRect)
        case .diagonal:     drawDiagonal(ctx: ctx, rect: drawRect)
        }

        // Draw detected subject indicator (face box)
        drawSubjectIndicator(ctx: ctx, rect: drawRect)
    }

    // MARK: ─────────── MOLECULE: Rule of Thirds ───────────

    /// Full 3×3 grid + highlighted intersection circles.
    /// The intersection nearest to the detected subject is highlighted.
    ///
    /// Reference: 2 vertical + 2 horizontal lines forming 9 equal zones.
    /// Power points (intersections) are the ideal subject positions.
    private func drawRuleOfThirds(ctx: CGContext, rect: CGRect) {
        let thirdW = rect.width  / 3
        let thirdH = rect.height / 3

        let color = guideColor

        // ── Atom: Secondary grid lines (full 3×3) ─────────────────────────
        drawLine(ctx, from: CGPoint(x: rect.minX + thirdW, y: rect.minY),
                       to:   CGPoint(x: rect.minX + thirdW, y: rect.maxY),
                       color: color, lineWidth: 1.5)
        drawLine(ctx, from: CGPoint(x: rect.minX + thirdW * 2, y: rect.minY),
                       to:   CGPoint(x: rect.minX + thirdW * 2, y: rect.maxY),
                       color: color, lineWidth: 1.5)
        drawLine(ctx, from: CGPoint(x: rect.minX, y: rect.minY + thirdH),
                       to:   CGPoint(x: rect.maxX, y: rect.minY + thirdH),
                       color: color, lineWidth: 1.5)
        drawLine(ctx, from: CGPoint(x: rect.minX, y: rect.minY + thirdH * 2),
                       to:   CGPoint(x: rect.maxX, y: rect.minY + thirdH * 2),
                       color: color, lineWidth: 1.5)

        // ── Atom: Intersection circles at all 4 power points ─────────────
        let intersections: [CGPoint] = [
            CGPoint(x: rect.minX + thirdW,     y: rect.minY + thirdH),
            CGPoint(x: rect.minX + thirdW * 2, y: rect.minY + thirdH),
            CGPoint(x: rect.minX + thirdW,     y: rect.minY + thirdH * 2),
            CGPoint(x: rect.minX + thirdW * 2, y: rect.minY + thirdH * 2),
        ]

        // Find nearest intersection to subject (if available)
        let subjectCentroid = geometry.saliencyCentroid ?? faceCenter()
        var nearestIndex: Int? = nil
        if let pt = subjectCentroid {
            var minDist = CGFloat.greatestFiniteMagnitude
            for (i, ip) in intersections.enumerated() {
                let normIP = CGPoint(
                    x: (ip.x - rect.minX) / rect.width,
                    y: (ip.y - rect.minY) / rect.height
                )
                let d = hypot(normIP.x - pt.x, normIP.y - pt.y)
                if d < minDist { minDist = d; nearestIndex = i }
            }
        }

        for (i, ip) in intersections.enumerated() {
            let isNearest = (i == nearestIndex)
            let circleRadius: CGFloat = isNearest ? 14 : 10

            // Outer circle ring
            drawCircle(ctx, center: ip, radius: circleRadius,
                       color: color, lineWidth: isNearest ? 2.5 : 1.5)

            // Crosshair inside each intersection circle
            drawCrosshair(ctx, center: ip, armLength: circleRadius * 0.6,
                          color: color, lineWidth: 1.0)

            // Glow effect for nearest intersection when aligned
            if isNearest && isPerfect {
                ctx.setShadow(offset: .zero, blur: 12, color: color.cgColor)
                drawCircle(ctx, center: ip, radius: circleRadius,
                           color: color, lineWidth: 3.0)
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
            }
        }

        // ── Atom: Dashed arrow from subject to nearest intersection ────────
        if let pt = subjectCentroid, let nearestIdx = nearestIndex, !isPerfect {
            let subjectPixel = denormalize(pt, in: rect)
            let targetPixel  = intersections[nearestIdx]
            drawDashedArrow(ctx, from: subjectPixel, to: targetPixel,
                            color: color.withAlphaComponent(0.5), lineWidth: 1.0)
        }
    }

    // MARK: ─────────── MOLECULE: Center ───────────

    /// Full 3×3 grid + large center circle target + crosshair.
    private func drawCenter(ctx: CGContext, rect: CGRect) {
        let color = guideColor
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // ── Atom: Subtle 3×3 grid background ──────────────────────────────
        let thirdW = rect.width  / 3
        let thirdH = rect.height / 3
        for i in 1...2 {
            let x = rect.minX + thirdW * CGFloat(i)
            drawLine(ctx, from: CGPoint(x: x, y: rect.minY),
                           to:   CGPoint(x: x, y: rect.maxY),
                           color: secondaryLineColor, lineWidth: 1.0)
        }
        for i in 1...2 {
            let y = rect.minY + thirdH * CGFloat(i)
            drawLine(ctx, from: CGPoint(x: rect.minX, y: y),
                           to:   CGPoint(x: rect.maxX, y: y),
                           color: secondaryLineColor, lineWidth: 1.0)
        }

        // ── Atom: Large center target circle ───────────────────────────────
        let targetRadius: CGFloat = min(rect.width, rect.height) * 0.15
        drawCircle(ctx, center: center, radius: targetRadius, color: color, lineWidth: 2.5)

        // ── Atom: Inner dot ────────────────────────────────────────────────
        ctx.setFillColor(color.cgColor)
        let dotRadius: CGFloat = 4
        ctx.fillEllipse(in: CGRect(
            x: center.x - dotRadius, y: center.y - dotRadius,
            width: dotRadius * 2, height: dotRadius * 2
        ))

        // ── Atom: Crosshair at center ──────────────────────────────────────
        drawCrosshair(ctx, center: center, armLength: targetRadius + 16,
                      color: color, lineWidth: isPerfect ? 2.5 : 1.5)

        // Glow when aligned
        if isPerfect {
            ctx.setShadow(offset: .zero, blur: 16, color: color.cgColor)
            drawCircle(ctx, center: center, radius: targetRadius, color: color, lineWidth: 3.0)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }

        // ── Atom: Arrow from subject to center ────────────────────────────
        if let centroid = geometry.saliencyCentroid ?? faceCenter(), !isPerfect {
            let subjectPixel = denormalize(centroid, in: rect)
            drawDashedArrow(ctx, from: subjectPixel, to: center,
                            color: color.withAlphaComponent(0.5), lineWidth: 1.0)
        }
    }

    // MARK: ─────────── MOLECULE: Horizontal ───────────

    /// Horizontal guide lines: one prominent center line + two thirds lines.
    /// Color is driven by whether a VISUAL HORIZON is detected in the scene.
    private func drawHorizontal(ctx: CGContext, rect: CGRect) {
        let color = guideColor

        // ── Atom: Upper and lower third lines (secondary) ─────────────────
        let topThirdY    = rect.minY + rect.height * 0.33
        let bottomThirdY = rect.minY + rect.height * 0.67
        drawLine(ctx, from: CGPoint(x: rect.minX, y: topThirdY),
                       to:   CGPoint(x: rect.maxX, y: topThirdY),
                       color: secondaryLineColor, lineWidth: 1.0, dashed: true)
        drawLine(ctx, from: CGPoint(x: rect.minX, y: bottomThirdY),
                       to:   CGPoint(x: rect.maxX, y: bottomThirdY),
                       color: secondaryLineColor, lineWidth: 1.0, dashed: true)

        // ── Atom: Centre horizon line (primary guide) ─────────────────────
        let centerY = rect.midY
        drawLine(ctx, from: CGPoint(x: rect.minX, y: centerY),
                       to:   CGPoint(x: rect.maxX, y: centerY),
                       color: color, lineWidth: 2.5)

        // ── Atom: Small centre tick marks ──────────────────────────────────
        let tickHeight: CGFloat = 12
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: rect.midX, y: centerY - tickHeight))
        ctx.addLine(to: CGPoint(x: rect.midX, y: centerY + tickHeight))
        ctx.strokePath()

        // Glow on the horizon line when scene is aligned
        if isPerfect {
            ctx.setShadow(offset: .zero, blur: 12, color: color.cgColor)
            drawLine(ctx, from: CGPoint(x: rect.minX, y: centerY),
                           to:   CGPoint(x: rect.maxX, y: centerY),
                           color: color, lineWidth: 3.0)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }

    // MARK: ─────────── MOLECULE: Vertical ───────────

    /// Vertical guide lines: prominent centre line + dashed thirds lines.
    private func drawVertical(ctx: CGContext, rect: CGRect) {
        let color = guideColor

        // ── Atom: Left and right third lines (secondary) ──────────────────
        let leftThirdX  = rect.minX + rect.width * 0.33
        let rightThirdX = rect.minX + rect.width * 0.67
        drawLine(ctx, from: CGPoint(x: leftThirdX, y: rect.minY),
                       to:   CGPoint(x: leftThirdX, y: rect.maxY),
                       color: secondaryLineColor, lineWidth: 1.0, dashed: true)
        drawLine(ctx, from: CGPoint(x: rightThirdX, y: rect.minY),
                       to:   CGPoint(x: rightThirdX, y: rect.maxY),
                       color: secondaryLineColor, lineWidth: 1.0, dashed: true)

        // ── Atom: Centre vertical line (primary guide) ────────────────────
        let centerX = rect.midX
        drawLine(ctx, from: CGPoint(x: centerX, y: rect.minY),
                       to:   CGPoint(x: centerX, y: rect.maxY),
                       color: color, lineWidth: 2.5)

        // ── Atom: Centre crosshair tick marks ─────────────────────────────
        let tickWidth: CGFloat = 12
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: centerX - tickWidth, y: rect.midY))
        ctx.addLine(to: CGPoint(x: centerX + tickWidth, y: rect.midY))
        ctx.strokePath()

        if isPerfect {
            ctx.setShadow(offset: .zero, blur: 12, color: color.cgColor)
            drawLine(ctx, from: CGPoint(x: centerX, y: rect.minY),
                           to:   CGPoint(x: centerX, y: rect.maxY),
                           color: color, lineWidth: 3.0)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }

    // MARK: ─────────── MOLECULE: Diagonal ───────────

    /// Two diagonal lines corner-to-corner + a crosshair at center.
    private func drawDiagonal(ctx: CGContext, rect: CGRect) {
        let color = guideColor

        // ── Atom: Full 3×3 background grid ────────────────────────────────
        let thirdW = rect.width  / 3
        let thirdH = rect.height / 3
        for i in 1...2 {
            let x = rect.minX + thirdW * CGFloat(i)
            drawLine(ctx, from: CGPoint(x: x, y: rect.minY),
                           to:   CGPoint(x: x, y: rect.maxY),
                           color: secondaryLineColor, lineWidth: 1.0)
        }
        for i in 1...2 {
            let y = rect.minY + thirdH * CGFloat(i)
            drawLine(ctx, from: CGPoint(x: rect.minX, y: y),
                           to:   CGPoint(x: rect.maxX, y: y),
                           color: secondaryLineColor, lineWidth: 1.0)
        }

        // ── Atom: Two diagonal lines ───────────────────────────────────────
        drawLine(ctx, from: CGPoint(x: rect.minX, y: rect.minY),
                       to:   CGPoint(x: rect.maxX, y: rect.maxY),
                       color: color, lineWidth: 2.0)
        drawLine(ctx, from: CGPoint(x: rect.maxX, y: rect.minY),
                       to:   CGPoint(x: rect.minX, y: rect.maxY),
                       color: color, lineWidth: 2.0)

        // ── Atom: Center crosshair ─────────────────────────────────────────
        let center = CGPoint(x: rect.midX, y: rect.midY)
        drawCrosshair(ctx, center: center, armLength: 14, color: color, lineWidth: 2.0)

        if isPerfect {
            ctx.setShadow(offset: .zero, blur: 12, color: color.cgColor)
            drawCrosshair(ctx, center: center, armLength: 14, color: color, lineWidth: 3.0)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }

    // MARK: ─────────── Subject Indicator ───────────

    /// Draws a dashed box around the detected face, tinted by alignment color.
    private func drawSubjectIndicator(ctx: CGContext, rect: CGRect) {
        guard let faceNorm = geometry.faceRect else { return }
        let faceRect = CGRect(
            x: rect.minX + faceNorm.origin.x * rect.width,
            y: rect.minY + faceNorm.origin.y * rect.height,
            width:  faceNorm.width  * rect.width,
            height: faceNorm.height * rect.height
        )
        let color = guideColor.withAlphaComponent(0.6)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [6, 3])
        ctx.stroke(faceRect)
        ctx.setLineDash(phase: 0, lengths: [])
    }

    // MARK: ─────────── Atom: Drawing Primitives ───────────

    /// Atom — draws a single straight line.
    private func drawLine(
        _ ctx: CGContext,
        from start: CGPoint,
        to end: CGPoint,
        color: UIColor,
        lineWidth: CGFloat,
        dashed: Bool = false
    ) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        if dashed {
            ctx.setLineDash(phase: 0, lengths: [8, 6])
        } else {
            ctx.setLineDash(phase: 0, lengths: [])
        }
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        if dashed { ctx.setLineDash(phase: 0, lengths: []) }
    }

    /// Atom — draws a circle (unfilled, stroked only).
    private func drawCircle(
        _ ctx: CGContext,
        center: CGPoint,
        radius: CGFloat,
        color: UIColor,
        lineWidth: CGFloat
    ) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.strokeEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    /// Atom — draws a + crosshair at a given center point.
    private func drawCrosshair(
        _ ctx: CGContext,
        center: CGPoint,
        armLength: CGFloat,
        color: UIColor,
        lineWidth: CGFloat
    ) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.move(to: CGPoint(x: center.x - armLength, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + armLength, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - armLength))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + armLength))
        ctx.strokePath()
    }

    /// Atom — draws a dashed line with a small arrowhead at the end.
    /// Used to show the user which direction to move the subject.
    private func drawDashedArrow(
        _ ctx: CGContext,
        from start: CGPoint,
        to end: CGPoint,
        color: UIColor,
        lineWidth: CGFloat
    ) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineDash(phase: 0, lengths: [5, 5])
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Arrowhead at the destination
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLen: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6   // 30°
        let p1 = CGPoint(
            x: end.x - arrowLen * cos(angle - arrowAngle),
            y: end.y - arrowLen * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLen * cos(angle + arrowAngle),
            y: end.y - arrowLen * sin(angle + arrowAngle)
        )
        ctx.setFillColor(color.cgColor)
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: ─────────── Helpers ───────────

    /// Converts a normalised point (0–1) to pixel coordinates within the rect.
    private func denormalize(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    /// Returns the center of the detected face bounding box.
    private func faceCenter() -> CGPoint? {
        guard let face = geometry.faceRect else { return nil }
        return CGPoint(x: face.midX, y: face.midY)
    }

    // MARK: ─────────── Aspect Mask ───────────

    /// Calculates the drawable rect based on the selected aspect ratio.
    private func aspectMaskedRect(in rect: CGRect) -> CGRect {
        guard aspectRatio != .free else { return rect }

        let ratio: CGFloat
        switch aspectRatio {
        case .oneOne:      ratio = 1.0
        case .fourThree:   ratio = 3.0 / 4.0
        case .sixteenNine: ratio = 9.0 / 16.0
        case .free:        return rect
        }

        var w = rect.width
        var h = w / ratio
        if h > rect.height { h = rect.height; w = h * ratio }

        return CGRect(
            x: rect.midX - w / 2,
            y: rect.midY - h / 2,
            width: w,
            height: h
        )
    }

    /// Draws a semi-transparent dim mask outside the active aspect ratio area.
    private func drawAspectMask(ctx: CGContext, full: CGRect, content: CGRect) {
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        ctx.fill(CGRect(x: full.minX,    y: full.minY,    width: full.width, height: content.minY - full.minY))
        ctx.fill(CGRect(x: full.minX,    y: content.maxY, width: full.width, height: full.maxY - content.maxY))
        ctx.fill(CGRect(x: full.minX,    y: content.minY, width: content.minX - full.minX, height: content.height))
        ctx.fill(CGRect(x: content.maxX, y: content.minY, width: full.maxX - content.maxX, height: content.height))
    }
}
