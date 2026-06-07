//
//  GridPrimitives.swift
//  Photograph
//
//  Reusable drawing primitives for composition overlay grids.
//  Grouped here because they are small, tightly coupled, and always
//  used together by the grid views (RuleOfThirdsGrid, CenterGrid, etc.).
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

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
                lineCap: .butt,
                dash: isDashed ? [8, 6] : []
            )
        )
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
                color.opacity(0.6),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
            )
        }
    }
}
