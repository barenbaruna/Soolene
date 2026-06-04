//
//  CompositionDirectionOverlay.swift
//  Photograph
//
//  A SwiftUI animated guidance layer that shows the user WHERE to aim.
//
//  ─────────────────────────────────────────────────────────────────────
//  Design Rationale
//  ─────────────────────────────────────────────────────────────────────
//  When a user holds the camera up to shoot, they're looking THROUGH the
//  viewfinder at the scene — not at UI text. Reading small directional arrows
//  in a 12pt text pill requires 4 cognitive steps:
//    1. Look at pill text
//    2. Parse arrow direction
//    3. Map to physical camera movement
//    4. Execute movement
//
//  Instead, this layer shows the directional guidance VISUALLY on the frame
//  itself using two elements:
//
//  1. PulsingTargetRing — animated circle at the IDEAL subject position
//     (the intersection point, center dot, etc.)
//     Pulses outward continuously to draw attention.
//     Color: Red = guide user there, Green = user is there.
//
//  2. BoldDirectionArrow — solid line + filled arrowhead from the
//     current subject position → target position.
//     3pt thick, 22pt arrowhead, clearly visible on any background.
//     Fades smoothly when the subject is aligned.
//
//  ─────────────────────────────────────────────────────────────────────
//  Atomic Design Structure
//  ─────────────────────────────────────────────────────────────────────
//  Atoms:     PulsingTargetRing, BoldDirectionArrow
//  Molecule:  CompositionDirectionOverlay
//  ─────────────────────────────────────────────────────────────────────
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

// MARK: - CompositionDirectionOverlay (Molecule)

/// Full-screen SwiftUI overlay that draws:
/// - A pulsing ring at the target position (where the subject SHOULD be)
/// - A bold arrow from the current subject position → target position
///
/// Uses `GeometryReader` to convert normalised positions to pixel positions,
/// and `Canvas` to draw the arrow cleanly on any background.
struct CompositionDirectionOverlay: View {
    let composition: CompositionType
    let subjectPoint: CGPoint?       // Best subject position (normalised 0–1, UIKit coords)
    let isPerfect: Bool
    let hasSceneData: Bool
    let alignmentScore: Float

    private var guideColor: Color {
        if !hasSceneData { return Color.white.opacity(0.7) }
        return alignmentScore >= 0.8 ? AppColors.gridlineGreen : AppColors.gridlineRed
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Only render when Vision has usable scene data
            if hasSceneData,
               let subNorm = subjectPoint,
               let targetNorm = targetPoint(for: composition, subject: subNorm)
            {
                let subPx    = toPixel(subNorm,    width: w, height: h)
                let targetPx = toPixel(targetNorm, width: w, height: h)
                let distance = hypot(subNorm.x - targetNorm.x, subNorm.y - targetNorm.y)

                ZStack {
                    // ── Atom 1: Pulsing ring at the TARGET position ─────────
                    PulsingTargetRing(color: guideColor, isPerfect: isPerfect)
                        .frame(width: 64, height: 64)
                        .position(targetPx)
                        .allowsHitTesting(false)

                    // ── Atom 2: Bold direction arrow (hidden when aligned) ───
                    if !isPerfect && distance > 0.06 {
                        BoldDirectionArrow(
                            from: subPx,
                            to: targetPx,
                            color: guideColor,
                            opacity: Double(min(1.0, distance * 4))  // Fade in with distance
                        )
                        .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: isPerfect)
                .animation(.easeInOut(duration: 0.4), value: alignmentScore)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Target Position per Composition

    /// Returns the ideal normalised target position for the subject,
    /// given the current composition type.
    private func targetPoint(for composition: CompositionType, subject: CGPoint) -> CGPoint? {
        switch composition {
        case .ruleOfThirds:
            // Nearest intersection to the current subject position
            let tx: CGFloat = subject.x < 0.5 ? 1.0 / 3.0 : 2.0 / 3.0
            let ty: CGFloat = subject.y < 0.5 ? 1.0 / 3.0 : 2.0 / 3.0
            return CGPoint(x: tx, y: ty)

        case .center:
            return CGPoint(x: 0.5, y: 0.5)

        case .horizontal:
            // For horizontal, guide the horizon to the center horizontal line
            return CGPoint(x: 0.5, y: 0.5)

        case .vertical:
            // Guide subject to the center vertical axis, keep current Y
            return CGPoint(x: 0.5, y: subject.y)

        case .diagonal:
            // Find the nearest point on either diagonal (y=x or y=1-x)
            let d1 = abs(subject.y - subject.x)           // Distance to y=x diagonal
            let d2 = abs(subject.y - (1 - subject.x))     // Distance to y=1-x diagonal
            if d1 < d2 {
                // Nearest point on y=x: parameter t minimises (x-t)²+(y-t)²
                let t = (subject.x + subject.y) / 2.0
                return CGPoint(x: t.clamped(to: 0.1...0.9), y: t.clamped(to: 0.1...0.9))
            } else {
                // Nearest point on y=1-x
                let t = (subject.x + (1 - subject.y)) / 2.0
                let clamped = t.clamped(to: 0.1...0.9)
                return CGPoint(x: clamped, y: 1 - clamped)
            }
        }
    }

    // MARK: - Coordinate Helper

    private func toPixel(_ norm: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: norm.x * width, y: norm.y * height)
    }
}

// MARK: - PulsingTargetRing (Atom)

/// An animated circle ring that pulses outward continuously.
/// Draws attention to the IDEAL position for the subject.
///
/// - Outer ring: fades out as it scales up (pulse effect)
/// - Inner ring: solid, always visible
/// - Center dot: indicates exact target point
private struct PulsingTargetRing: View {
    let color: Color
    let isPerfect: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring — scales 1.0 → 1.6 and fades out
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)
                .animation(
                    .easeOut(duration: 1.3).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // Inner ring — always visible
            Circle()
                .stroke(color, lineWidth: 2.5)

            // Center dot
            Circle()
                .fill(color)
                .frame(width: isPerfect ? 12 : 8, height: isPerfect ? 12 : 8)
                .animation(.spring(response: 0.3), value: isPerfect)

            // Success glow when perfect
            if isPerfect {
                Circle()
                    .fill(color.opacity(0.25))
                    .scaleEffect(1.2)
            }
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - BoldDirectionArrow (Atom)

/// A full-screen Canvas that draws a solid directional arrow
/// from the current subject position → the ideal target position.
///
/// Design decisions:
/// - Solid line (not dashed) — easier to follow direction at a glance
/// - 3pt shaft, filled triangular arrowhead
/// - Line stops 8pt before the arrowhead tip for visual clarity
private struct BoldDirectionArrow: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let opacity: Double

    var body: some View {
        Canvas { ctx, _ in
            guard hypot(to.x - from.x, to.y - from.y) > 20 else { return }

            let angle = atan2(to.y - from.y, to.x - from.x)
            let arrowLength: CGFloat = 22
            let arrowAngle: CGFloat  = .pi / 5   // 36° → wide, clearly visible arrowhead

            // The line ends slightly before the tip so it doesn't overlap the arrowhead
            let shaftEnd = CGPoint(
                x: to.x - arrowLength * 0.6 * cos(angle),
                y: to.y - arrowLength * 0.6 * sin(angle)
            )

            // ── Shaft ─────────────────────────────────────────────────────
            var shaft = Path()
            shaft.move(to: from)
            shaft.addLine(to: shaftEnd)
            ctx.stroke(
                shaft,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

            // ── Arrowhead (filled triangle) ───────────────────────────────
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

// MARK: - Comparable Clamping Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
