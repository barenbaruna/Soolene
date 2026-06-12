//
//  AspectMask.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws a semi-transparent dim mask outside the active aspect ratio area.
struct AspectMask: View {
    let fullRect: CGRect
    let contentRect: CGRect

    var body: some View {
        Path { path in
            // Top
            path.addRect(CGRect(x: fullRect.minX, y: fullRect.minY, width: fullRect.width, height: contentRect.minY - fullRect.minY))
            // Bottom
            path.addRect(CGRect(x: fullRect.minX, y: contentRect.maxY, width: fullRect.width, height: fullRect.maxY - contentRect.maxY))
            // Left
            path.addRect(CGRect(x: fullRect.minX, y: contentRect.minY, width: contentRect.minX - fullRect.minX, height: contentRect.height))
            // Right
            path.addRect(CGRect(x: contentRect.maxX, y: contentRect.minY, width: fullRect.maxX - contentRect.maxX, height: contentRect.height))
        }
        .fill(Color.black.opacity(0.5))
    }
}
