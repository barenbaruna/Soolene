//
//  DiagonalGrid.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct DiagonalGrid: View {
    let rect: CGRect
    let color: Color
    let isPerfect: Bool
    
    private let secondaryColor = Color.white.opacity(0.25)
    
    var body: some View {
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        ZStack {
            // Full 3x3 background grid
            ForEach(1...2, id: \.self) { i in
                GridLineAtom(start: CGPoint(x: rect.minX + thirdW * CGFloat(i), y: rect.minY), end: CGPoint(x: rect.minX + thirdW * CGFloat(i), y: rect.maxY), color: secondaryColor, lineWidth: 1.0, isDashed: false)
                GridLineAtom(start: CGPoint(x: rect.minX, y: rect.minY + thirdH * CGFloat(i)), end: CGPoint(x: rect.maxX, y: rect.minY + thirdH * CGFloat(i)), color: secondaryColor, lineWidth: 1.0, isDashed: false)
            }
            
            // Two diagonal lines
            GridLineAtom(start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), color: color, lineWidth: 2.0, isDashed: false)
            GridLineAtom(start: CGPoint(x: rect.maxX, y: rect.minY), end: CGPoint(x: rect.minX, y: rect.maxY), color: color, lineWidth: 2.0, isDashed: false)
            
            // Center crosshair
            CrosshairAtom(center: center, armLength: 14, color: color, lineWidth: 2.0)
            
            if isPerfect {
                CrosshairAtom(center: center, armLength: 14, color: color, lineWidth: 3.0)
                    .shadow(color: color, radius: 12)
            }
        }
    }
}
