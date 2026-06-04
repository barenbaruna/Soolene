//
//  CrosshairAtom.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws a + crosshair at the given center.
struct CrosshairAtom: View {
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
