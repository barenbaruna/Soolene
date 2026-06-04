//
//  AlignmentAnalyzer.swift
//  Photograph
//
//  Handles the complex math for composition scoring and subject offset.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreGraphics
import Foundation

struct AlignmentAnalyzer {
    
    // MARK: - Scene Alignment Score
    
    /// Computes a 0.0–1.0 score representing how well the scene content
    /// matches the chosen composition.
    static func computeSceneAlignmentScore(
        for composition: CompositionType,
        geometry: SceneGeometry,
        isPerfect: Bool
    ) -> Float {
        switch composition {
        
        case .ruleOfThirds, .center, .diagonal:
            let hasSubject = geometry.faceRect != nil
                          || geometry.bodyCenter != nil
                          || geometry.saliencyCentroid != nil
            guard hasSubject else { return 0.0 }
            return isPerfect ? 0.95 : 0.4
            
        case .horizontal:
            guard geometry.horizonAngle != 0 else { return 0.0 }
            let angleDeg = abs(geometry.horizonAngle)
            if angleDeg < 2.0  { return 0.95 }
            if angleDeg < 8.0  { return 0.5  }
            return 0.3
            
        case .vertical:
            let hasSubject = geometry.bodyCenter != nil || geometry.saliencyBounds != nil
            guard hasSubject || geometry.hasStrongVerticals else { return 0.0 }
            if geometry.hasStrongVerticals { return isPerfect ? 0.95 : 0.55 }
            
            if let bounds = geometry.saliencyBounds {
                let isVerticalSubject = bounds.height > bounds.width * 1.3
                if isVerticalSubject { return isPerfect ? 0.9 : 0.5 }
            }
            return 0.35
        }
    }
    
    // MARK: - Subject Offset
    
    /// Returns the direction vector FROM the subject TO its ideal target position,
    /// and whether the subject is close enough to be considered "perfect".
    static func computeSubjectOffset(
        for composition: CompositionType,
        geometry: SceneGeometry
    ) -> (vector: CGVector, isPerfect: Bool) {
        
        let subjectPoint: CGPoint?
        if let face = geometry.faceRect {
            subjectPoint = CGPoint(x: face.midX, y: face.midY)
        } else if let body = geometry.bodyCenter {
            subjectPoint = body
        } else {
            subjectPoint = geometry.saliencyCentroid
        }
        
        guard let pt = subjectPoint else { return (.zero, false) }
        
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        
        switch composition {
        case .ruleOfThirds:
            let targetX: CGFloat = pt.x < 0.5 ? 0.33 : 0.67
            let targetY: CGFloat = pt.y < 0.5 ? 0.33 : 0.67
            dx = targetX - pt.x
            dy = targetY - pt.y
            
        case .center:
            dx = 0.5 - pt.x
            dy = 0.5 - pt.y
            
        case .horizontal:
            dx = 0
            dy = 0.5 - pt.y
            
        case .vertical:
            dx = 0.5 - pt.x
            dy = 0
            
        case .diagonal:
            let distToDiag1 = abs(pt.y - pt.x) / sqrt(2)
            let distToDiag2 = abs(pt.y - (1 - pt.x)) / sqrt(2)
            let minDist = min(distToDiag1, distToDiag2)
            if minDist > 0.08 {
                dx = 0.5 - pt.x
                dy = 0.5 - pt.y
            }
        }
        
        let distance = hypot(dx, dy)
        let isPerfect = distance < 0.08
        return (CGVector(dx: dx, dy: dy), isPerfect)
    }
}
