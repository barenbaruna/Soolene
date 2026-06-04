//
//  GridLineAtom.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws a single straight line. Can be solid or dashed.
struct GridLineAtom: View {
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
