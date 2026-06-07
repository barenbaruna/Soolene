//
//  CompositionDirectionOverlay.swift
//  Photograph
//
//  Dual-Anchor guidance overlay rendered on top of the camera preview.
//
//  Visual design (Apple HIG Alignment):
//  - Subject Anchor: A corner bracket [ ] (familiar standard for focus/AE lock).
//  - Target Socket: A pulsing circle (standard for destinations).
//  - Connector: A solid line with a drop shadow to ensure visibility across
//    all light/dark backgrounds.
//
//  States:
//    Far       — guidanceDistance > 0.12. Both anchors + connector visible.
//    Close     — guidanceDistance 0.06–0.12. Connector hidden, socket turns gold.
//    Perfect   — guidanceDistance < 0.06. Both anchors turn green, socket glows.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

// MARK: - CompositionDirectionOverlay

struct CompositionDirectionOverlay: View {
    let composition: CompositionType
    let subjectPoint: CGPoint?
    let targetPoint: CGPoint?
    let isPerfect: Bool
    let hasSceneData: Bool
    let hasMLData: Bool
    let alignmentScore: Float
    let guidanceDistance: CGFloat

    // MARK: - Anchor Colours

    private var anchorColor: Color {
        if isPerfect { return AppColors.gridlineGreen }
        if guidanceDistance < 0.12 { return AppColors.primary }
        return Color.white.opacity(0.85)
    }

    // MARK: - Body

    var body: some View {
        guard hasMLData, hasSceneData else { return AnyView(EmptyView()) }

        return AnyView(
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                if let subjectNorm = subjectPoint, let targetNorm = targetPoint {
                    let subjectPx = toPixel(subjectNorm, width: w, height: h)
                    let targetPx  = toPixel(targetNorm,  width: w, height: h)

                    ZStack {
                        // Connector line — visible only when far from target.
                        // Solid line with shadow for high contrast.
                        if !isPerfect && guidanceDistance > 0.12 {
                            ConnectorLine(from: subjectPx, to: targetPx, color: anchorColor)
                                .allowsHitTesting(false)
                        }

                        // Target socket (Circle) — marks the destination.
                        let socketSize: CGFloat = guidanceDistance < 0.12 ? 72 : 60
                        TargetSocket(color: anchorColor, isPerfect: isPerfect)
                            .frame(width: socketSize, height: socketSize)
                            .position(targetPx)
                            .allowsHitTesting(false)

                        // Subject anchor (Bracket) — marks the current object.
                        SubjectReticle(color: anchorColor, isPerfect: isPerfect)
                            .frame(width: 44, height: 44)
                            .position(subjectPx)
                            .allowsHitTesting(false)
                    }
                    // Physics-based fluid tracking (HCI best practice).
                    // .interpolatingSpring preserves velocity momentum across frequent 60fps updates,
                    // preventing the stuttering caused by standard .spring() which resets every frame.
                    .animation(.interpolatingSpring(stiffness: 150, damping: 15), value: targetPx)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 15), value: subjectPx)
                    .animation(.easeInOut(duration: 0.3), value: isPerfect)
                    .animation(.easeInOut(duration: 0.3), value: guidanceDistance < 0.12)
                }
            }
            .allowsHitTesting(false)
        )
    }

    private func toPixel(_ norm: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: norm.x * width, y: norm.y * height)
    }
}

// MARK: - SubjectReticle

/// A corner bracket [ ] that marks the current subject position,
/// mimicking the native iOS camera focus lock indicator.
private struct SubjectReticle: View {
    let color: Color
    let isPerfect: Bool

    var body: some View {
        ZStack {
            if isPerfect {
                Color.clear // Removing fill to keep the bracket clean
            }
            
            // Corner brackets using a custom shape
            BracketShape()
                .stroke(color, style: StrokeStyle(lineWidth: isPerfect ? 2.5 : 1.5, lineCap: .square, lineJoin: .miter))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
}

/// Draws four corners like a camera viewfinder bracket: [ ]
private struct BracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = rect.width * 0.25 // Length of each corner arm

        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        // Top Right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        // Bottom Left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}

// MARK: - TargetSocket

/// A pulsing ring at the ideal composition position.
private struct TargetSocket: View {
    let color: Color
    let isPerfect: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulse ring
            if isPerfect {
                Circle()
                    .strokeBorder(color.opacity(isPulsing ? 0 : 0.5), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .animation(
                        .easeOut(duration: 0.8).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                    .onAppear { isPulsing = true }
                    .onDisappear { isPulsing = false }
            }

            // Inner socket ring
            Circle()
                .strokeBorder(color, lineWidth: isPerfect ? 2.5 : 1.5)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

            // Centre dot
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - ConnectorLine

/// A solid line between the subject reticle and the target socket.
private struct ConnectorLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            // Shadow for contrast
            context.stroke(
                path,
                with: .color(.black.opacity(0.3)),
                style: StrokeStyle(lineWidth: 2.5)
            )
            // Main line
            context.stroke(
                path,
                with: .color(color.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }
    }
}
