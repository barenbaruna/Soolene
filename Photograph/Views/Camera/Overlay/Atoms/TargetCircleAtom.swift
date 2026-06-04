//
//  TargetCircleAtom.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws an unfilled circle (ring).
struct TargetCircleAtom: View {
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
