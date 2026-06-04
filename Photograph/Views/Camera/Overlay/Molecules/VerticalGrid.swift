//
//  VerticalGrid.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct VerticalGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool
    
    private let secondaryColor = Color.white.opacity(0.25)
    
    var body: some View {
        let leftThirdX = rect.minX + rect.width * 0.33
        let rightThirdX = rect.minX + rect.width * 0.67
        let centerX = rect.midX
        let tickWidth: CGFloat = 12
        
        ZStack {
            // Left and right third lines
            GridLineAtom(start: CGPoint(x: leftThirdX, y: rect.minY), end: CGPoint(x: leftThirdX, y: rect.maxY), color: secondaryColor, lineWidth: 1.0, isDashed: true)
            GridLineAtom(start: CGPoint(x: rightThirdX, y: rect.minY), end: CGPoint(x: rightThirdX, y: rect.maxY), color: secondaryColor, lineWidth: 1.0, isDashed: true)
            
            // Centre vertical line
            GridLineAtom(start: CGPoint(x: centerX, y: rect.minY), end: CGPoint(x: centerX, y: rect.maxY), color: color, lineWidth: 2.5, isDashed: false)
            
            // Centre tick mark
            GridLineAtom(start: CGPoint(x: centerX - tickWidth, y: rect.midY), end: CGPoint(x: centerX + tickWidth, y: rect.midY), color: color, lineWidth: 2.0, isDashed: false)
            
            // Glow effect
            if isPerfect {
                GridLineAtom(start: CGPoint(x: centerX, y: rect.minY), end: CGPoint(x: centerX, y: rect.maxY), color: color, lineWidth: 3.0, isDashed: false)
                    .shadow(color: color, radius: 12)
            }
        }
    }
}
