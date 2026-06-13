//
//  RuleOfThirdsGrid.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

struct RuleOfThirdsGrid: View {
    let rect: CGRect
    let color: Color
    let geometry: SceneGeometry
    var lockedTarget: CGPoint?
    let isPerfect: Bool
    var showsIntersectionMarkers: Bool = true
    
    var body: some View {
        ZStack {
            // Secondary grid lines (full 3x3)
            GridLine(start: CGPoint(x: rect.minX + thirdW, y: rect.minY), end: CGPoint(x: rect.minX + thirdW, y: rect.maxY), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            GridLine(start: CGPoint(x: rect.minX + thirdW * 2, y: rect.minY), end: CGPoint(x: rect.minX + thirdW * 2, y: rect.maxY), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            GridLine(start: CGPoint(x: rect.minX, y: rect.minY + thirdH), end: CGPoint(x: rect.maxX, y: rect.minY + thirdH), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            GridLine(start: CGPoint(x: rect.minX, y: rect.minY + thirdH * 2), end: CGPoint(x: rect.maxX, y: rect.minY + thirdH * 2), color: color, lineWidth: GridMetrics.primary, isDashed: false)
            
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
    
    private var thirdW: CGFloat {
        rect.width / 3
    }

    private var thirdH: CGFloat {
        rect.height / 3
    }
    
    private var intersections: [CGPoint] {
        [
            CGPoint(x: rect.minX + thirdW, y: rect.minY + thirdH),
            CGPoint(x: rect.minX + thirdW * 2, y: rect.minY + thirdH),
            CGPoint(x: rect.minX + thirdW, y: rect.minY + thirdH * 2),
            CGPoint(x: rect.minX + thirdW * 2, y: rect.minY + thirdH * 2)
        ]
    }
    
    private var nearestIndex: Int? {
        if let lockedTarget {
            var nearest: Int? = nil
            var minDist = CGFloat.greatestFiniteMagnitude
            for (i, ip) in intersections.enumerated() {
                let normIP = CGPoint(
                    x: (ip.x - rect.minX) / rect.width,
                    y: (ip.y - rect.minY) / rect.height
                )
                let d = hypot(normIP.x - lockedTarget.x, normIP.y - lockedTarget.y)
                if d < minDist { minDist = d; nearest = i }
            }
            return nearest
        }

        let pt = geometry.saliencyCentroid ?? faceCenter
        guard let subject = pt else { return nil }

        var nearest: Int? = nil
        var minDist = CGFloat.greatestFiniteMagnitude
        for (i, ip) in intersections.enumerated() {
            let normIP = CGPoint(
                x: (ip.x - rect.minX) / rect.width,
                y: (ip.y - rect.minY) / rect.height
            )
            let d = hypot(normIP.x - subject.x, normIP.y - subject.y)
            if d < minDist { minDist = d; nearest = i }
        }
        return nearest
    }
    
    private var faceCenter: CGPoint? {
        guard let face = geometry.faceRects.first else { return nil }
        return CGPoint(x: face.midX, y: face.midY)
    }
}
