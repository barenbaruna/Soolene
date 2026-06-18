//
//  RuleOfThirdsGrid.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct RuleOfThirdsGrid: View {
    let size: CGSize
    let color: Color
    let fullRect: CGRect
    let aspectRect: CGRect
    let geometry: SceneGeometry
    var lockedTarget: CGPoint?
    let isPerfect: Bool
    var showsIntersectionMarkers: Bool = true
    
    var body: some View {
        ZStack {
            // Secondary grid lines (full 3x3)
            GridLine(start: CGPoint(x: thirdW, y: 0), end: CGPoint(x: thirdW, y: size.height), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            GridLine(start: CGPoint(x: thirdW * 2, y: 0), end: CGPoint(x: thirdW * 2, y: size.height), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            GridLine(start: CGPoint(x: 0, y: thirdH), end: CGPoint(x: size.width, y: thirdH), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            GridLine(start: CGPoint(x: 0, y: thirdH * 2), end: CGPoint(x: size.width, y: thirdH * 2), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            
            if showsIntersectionMarkers {
                ForEach(0 ..< 4, id: \.self) { i in
                    let ip = intersections[i]
                    let isNearest = (i == nearestIndex)
                    let circleRadius: CGFloat = isNearest ? 14 : 10
                    
                    TargetCircle(center: ip, radius: circleRadius, color: color, lineWidth: isNearest ? GridMetrics.targetRing : GridMetrics.secondary)
                    Crosshair(center: ip, armLength: circleRadius * 0.6, color: color, lineWidth: GridMetrics.crosshair)
                    
                    if isNearest && isPerfect {
                        TargetCircle(center: ip, radius: circleRadius, color: color, lineWidth: GridMetrics.targetRingEmphasis)
                            .shadow(color: color, radius: 12)
                    }
                }
            }
        }
    }
    
    // MARK: - Layout Helpers
    
    private var thirdW: CGFloat { size.width / 3 }
    private var thirdH: CGFloat { size.height / 3 }
    
    private var intersections: [CGPoint] {
        [
            CGPoint(x: thirdW, y: thirdH),
            CGPoint(x: thirdW * 2, y: thirdH),
            CGPoint(x: thirdW, y: thirdH * 2),
            CGPoint(x: thirdW * 2, y: thirdH * 2)
        ]
    }
    
    private func localPoint(for normalized: CGPoint) -> CGPoint {
        let screenX = fullRect.minX + normalized.x * fullRect.width
        let screenY = fullRect.minY + normalized.y * fullRect.height
        return CGPoint(x: screenX - aspectRect.minX, y: screenY - aspectRect.minY)
    }
    
    private var nearestIndex: Int? {
        let targetPt: CGPoint?
        if let locked = lockedTarget {
            targetPt = locked
        } else if let pt = geometry.saliencyCentroid ?? faceCenter {
            targetPt = pt
        } else {
            return nil
        }

        guard let target = targetPt else { return nil }
        let localTarget = localPoint(for: target)

        var nearest: Int? = nil
        var minDist = CGFloat.greatestFiniteMagnitude
        for (i, ip) in intersections.enumerated() {
            let d = hypot(ip.x - localTarget.x, ip.y - localTarget.y)
            if d < minDist { minDist = d; nearest = i }
        }
        return nearest
    }
    
    private var faceCenter: CGPoint? {
        guard let face = geometry.faceRects.first else { return nil }
        return CGPoint(x: face.midX, y: face.midY)
    }
}
