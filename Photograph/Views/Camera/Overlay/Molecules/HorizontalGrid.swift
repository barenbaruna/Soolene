//
//  HorizontalGrid.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct HorizontalGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool
    
    private let secondaryColor = Color.white.opacity(0.25)
    
    var body: some View {
        let topThirdY = rect.minY + rect.height * 0.33
        let bottomThirdY = rect.minY + rect.height * 0.67
        let centerY = rect.midY
        let tickHeight: CGFloat = 12
        
        ZStack {
            // Upper and lower third lines
            GridLineAtom(start: CGPoint(x: rect.minX, y: topThirdY), end: CGPoint(x: rect.maxX, y: topThirdY), color: secondaryColor, lineWidth: 1.0, isDashed: true)
            GridLineAtom(start: CGPoint(x: rect.minX, y: bottomThirdY), end: CGPoint(x: rect.maxX, y: bottomThirdY), color: secondaryColor, lineWidth: 1.0, isDashed: true)
            
            // Centre horizon line
            GridLineAtom(start: CGPoint(x: rect.minX, y: centerY), end: CGPoint(x: rect.maxX, y: centerY), color: color, lineWidth: 2.5, isDashed: false)
            
            // Small centre tick mark
            GridLineAtom(start: CGPoint(x: rect.midX, y: centerY - tickHeight), end: CGPoint(x: rect.midX, y: centerY + tickHeight), color: color, lineWidth: 2.0, isDashed: false)
            
            // Glow on horizon line
            if isPerfect {
                GridLineAtom(start: CGPoint(x: rect.minX, y: centerY), end: CGPoint(x: rect.maxX, y: centerY), color: color, lineWidth: 3.0, isDashed: false)
                    .shadow(color: color, radius: 12)
            }
        }
    }
}
