//
//  CenterGrid.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct CenterGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool
    
    private let secondaryColor = Color.white.opacity(0.25)
    
    var body: some View {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3
        let targetRadius = min(rect.width, rect.height) * 0.15
        
        ZStack {
            // Subtle 3x3 background
            ForEach(1...2, id: \.self) { i in
                GridLineAtom(start: CGPoint(x: rect.minX + thirdW * CGFloat(i), y: rect.minY), end: CGPoint(x: rect.minX + thirdW * CGFloat(i), y: rect.maxY), color: secondaryColor, lineWidth: 1.0, isDashed: false)
                GridLineAtom(start: CGPoint(x: rect.minX, y: rect.minY + thirdH * CGFloat(i)), end: CGPoint(x: rect.maxX, y: rect.minY + thirdH * CGFloat(i)), color: secondaryColor, lineWidth: 1.0, isDashed: false)
            }
            
            // Center target circle
            TargetCircleAtom(center: center, radius: targetRadius, color: color, lineWidth: 2.5)
            
            // Inner dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .position(center)
            
            // Crosshair
            CrosshairAtom(center: center, armLength: targetRadius + 16, color: color, lineWidth: isPerfect ? 2.5 : 1.5)
            
            // Glow effect
            if isPerfect {
                TargetCircleAtom(center: center, radius: targetRadius, color: color, lineWidth: 3.0)
                    .shadow(color: color, radius: 16)
            }
        }
    }
}
