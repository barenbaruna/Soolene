//
//  AspectMask.swift
//  Soolene
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws a semi-transparent dim mask outside the active aspect ratio area.
struct AspectMask: View {
    let fullRect: CGRect
    let contentRect: CGRect

    var body: some View {
        outsidePath
            .fill(Color.black.opacity(0.28))
    }

    private var outsidePath: Path {
        Path { path in
            path.addRect(CGRect(
                x: fullRect.minX,
                y: fullRect.minY,
                width: fullRect.width,
                height: max(0, contentRect.minY - fullRect.minY)
            ))
            path.addRect(CGRect(
                x: fullRect.minX,
                y: contentRect.maxY,
                width: fullRect.width,
                height: max(0, fullRect.maxY - contentRect.maxY)
            ))
            path.addRect(CGRect(
                x: fullRect.minX,
                y: contentRect.minY,
                width: max(0, contentRect.minX - fullRect.minX),
                height: contentRect.height
            ))
            path.addRect(CGRect(
                x: contentRect.maxX,
                y: contentRect.minY,
                width: max(0, fullRect.maxX - contentRect.maxX),
                height: contentRect.height
            ))
        }
    }
}
