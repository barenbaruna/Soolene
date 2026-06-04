//
//  SubjectBoxAtom.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Draws a dashed bounding box around the detected subject.
struct SubjectBoxAtom: View {
    let faceRect: CGRect?
    let frameRect: CGRect
    let color: Color
    
    var body: some View {
        if let faceNorm = faceRect {
            let rect = CGRect(
                x: frameRect.minX + faceNorm.origin.x * frameRect.width,
                y: frameRect.minY + faceNorm.origin.y * frameRect.height,
                width:  faceNorm.width  * frameRect.width,
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
