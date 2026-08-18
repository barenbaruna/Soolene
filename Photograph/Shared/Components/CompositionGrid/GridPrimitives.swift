//
//  GridPrimitives.swift
//  Soolene
//
//  Reusable drawing primitives for composition overlay grids.
//  Grouped here because they are small, tightly coupled, and always
//  used together by the grid views (RuleOfThirdsGrid, CenterGrid, etc.).
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

// MARK: - Grid Metrics

/// Shared stroke weights for composition overlays — readable on live camera feed.
enum GridMetrics {
    static let primary: CGFloat = 3.5
    static let secondary: CGFloat = 2.0
    static let tick: CGFloat = 2.5
    static let emphasis: CGFloat = 4.5
    static let crosshair: CGFloat = 2.5
    static let targetRing: CGFloat = 3.0
    static let targetRingEmphasis: CGFloat = 4.0

    /// Muted reference lines that stay subordinate to primary guides.
    static let guideMuted = AppColors.textGuide.opacity(0.45)
}

// MARK: - GridLine

/// Draws a single straight line between two points. Supports solid or dashed styles.
struct GridLine: View {
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
    let isDashed: Bool

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            color,
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                dash: isDashed ? [10, 7] : []
            )
        )
        .shadow(color: .black.opacity(0.45), radius: 1, x: 0, y: 0)
    }
}

// MARK: - TargetCircle

/// Draws an unfilled circle (ring) at a given center point.
struct TargetCircle: View {
    let center: CGPoint
    let radius: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Path { path in
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        .stroke(color, lineWidth: lineWidth)
        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0)
    }
}

// MARK: - Crosshair

/// Draws a + crosshair at a given center point.
struct Crosshair: View {
    let center: CGPoint
    let armLength: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: center.x - armLength, y: center.y))
            path.addLine(to: CGPoint(x: center.x + armLength, y: center.y))

            path.move(to: CGPoint(x: center.x, y: center.y - armLength))
            path.addLine(to: CGPoint(x: center.x, y: center.y + armLength))
        }
        .stroke(color, lineWidth: lineWidth)
        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0)
    }
}

// MARK: - SubjectBox

/// Draws a dashed bounding box around the detected subject (face rectangle).
struct SubjectBox: View {
    let faceRect: CGRect?
    let frameRect: CGRect
    let color: Color

    var body: some View {
        if let faceNorm = faceRect {
            let rect = CGRect(
                x: frameRect.minX + faceNorm.origin.x * frameRect.width,
                y: frameRect.minY + faceNorm.origin.y * frameRect.height,
                width: faceNorm.width * frameRect.width,
                height: faceNorm.height * frameRect.height
            )

            Path { path in
                path.addRect(rect)
            }
            .stroke(
                color.opacity(0.75),
                style: StrokeStyle(lineWidth: GridMetrics.secondary, dash: [8, 5])
            )
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0)
        }
    }
}
