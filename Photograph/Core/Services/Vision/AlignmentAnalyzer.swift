//
//  AlignmentAnalyzer.swift
//  Photograph
//
//  Computes subject offset and scene alignment score from SceneGeometry data.
//
//  Design notes:
//  - All coordinates are normalised (0–1), UIKit origin (top-left).
//  - "isPerfect" threshold is 0.06 normalised distance (~6% of frame width/height).
//  - Alignment score is continuous (0.0–1.0), not binary. This gives smooth
//    Red→Green colour transitions in the overlay.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import CoreGraphics
import Foundation

struct AlignmentAnalyzer {

    // MARK: - Constants

    /// Below this normalised distance, the subject is considered "perfectly placed".
    private static let perfectThreshold: CGFloat = 0.06

    // MARK: - Subject Point Resolution

    /// Returns the best available subject position using the priority chain:
    /// userPinnedSubject > face centroid > body center > saliency centroid
    static func resolveSubjectPoint(from geometry: SceneGeometry, depthData: AVDepthData? = nil) -> CGPoint? {
        if let pinned = geometry.userPinnedSubject { return pinned }

        // Multi-face resolution (raw, unsmoothed — used only on first frame before smoother initialises)
        if !geometry.faceRects.isEmpty {
            if let depthData = depthData {
                // Jalur A: LiDAR/Depth Map Tersedia (Akurasi Maksimal)
                // Evaluasi kedalaman absolut (meter) dari setiap wajah
                var closestFace: CGPoint?
                var minDistance: Float = .infinity
                
                for face in geometry.faceRects {
                    let center = CGPoint(x: face.midX, y: face.midY)
                    if let depth = DepthAnalyzer.extractDepth(at: center, from: depthData), depth < minDistance {
                        minDistance = depth
                        closestFace = center
                    }
                }
                
                if let bestFace = closestFace {
                    return bestFace
                }
            }
            
            // Jalur B: Tanpa Depth Map (Graceful Fallback)
            // Evaluasi Saliency-Weighted Area: Wajah terbesar + Paling dekat ke pusat perhatian
            let saliencyAnchor = geometry.saliencyCentroid ?? CGPoint(x: 0.5, y: 0.5)
            var bestFace: CGPoint?
            var bestScore: CGFloat = -1
            
            for face in geometry.faceRects {
                let area = face.width * face.height
                let center = CGPoint(x: face.midX, y: face.midY)
                let distToSaliency = hypot(center.x - saliencyAnchor.x, center.y - saliencyAnchor.y)
                
                // Bobot: Area besar (bagus) / Jarak ke saliency (jika jauh, penalty)
                let distancePenalty = max(distToSaliency, 0.05) // Mencegah bagi-nol, min penalty 5%
                let score = area / distancePenalty
                
                if score > bestScore {
                    bestScore = score
                    bestFace = center
                }
            }
            
            if let bestFace = bestFace {
                return bestFace
            }
        }

        if let body = geometry.bodyCenter { return body }
        if let objectness = geometry.objectnessCentroid { return objectness }
        return geometry.saliencyCentroid
    }

    // MARK: - Target Position per Composition

    /// Returns the ideal normalised target position for the subject,
    /// given the current composition type and the subject's current position.
    static func targetPoint(for composition: CompositionType, subject: CGPoint, geometry: SceneGeometry) -> CGPoint? {
        if let locked = geometry.lockedTargetPoint {
            return locked
        }

        switch composition {

        case .ruleOfThirds:
            // Four intersection points of the rule-of-thirds grid
            let intersections: [CGPoint] = [
                CGPoint(x: 1.0/3.0, y: 1.0/3.0),
                CGPoint(x: 2.0/3.0, y: 1.0/3.0),
                CGPoint(x: 1.0/3.0, y: 2.0/3.0),
                CGPoint(x: 2.0/3.0, y: 2.0/3.0)
            ]
            // Guide to the nearest intersection
            return intersections.min(by: {
                distanceSquared($0, subject) < distanceSquared($1, subject)
            })

        case .center:
            return CGPoint(x: 0.5, y: 0.5)

        case .horizontal:
            // Guide the subject/horizon to horizontal center line, preserving X
            return CGPoint(x: subject.x, y: 0.5)

        case .vertical:
            // Guide the subject to the center vertical axis, preserve Y
            return CGPoint(x: 0.5, y: subject.y)

        case .diagonal:
            // Two diagonals: y=x (top-left→bottom-right) and y=1−x (top-right→bottom-left)
            let onDiag1 = nearestPointOnSegment(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1, y: 1), point: subject)
            let onDiag2 = nearestPointOnSegment(from: CGPoint(x: 1, y: 0), to: CGPoint(x: 0, y: 1), point: subject)
            let d1 = distance(onDiag1, subject)
            let d2 = distance(onDiag2, subject)
            return d1 <= d2 ? onDiag1 : onDiag2
        }
    }

    // MARK: - Subject Offset

    /// Returns the vector FROM the subject TO its ideal target position,
    /// and whether the subject is within the perfect threshold.
    static func computeSubjectOffset(
        for composition: CompositionType,
        geometry: SceneGeometry,
        depthData: AVDepthData? = nil
    ) -> (vector: CGVector, isPerfect: Bool) {
        guard let subject = geometry.smoothedSubjectPoint ?? resolveSubjectPoint(from: geometry, depthData: depthData),
              let target  = targetPoint(for: composition, subject: subject, geometry: geometry)
        else {
            return (.zero, false)
        }

        let dx = target.x - subject.x
        let dy = target.y - subject.y
        let dist = hypot(dx, dy)
        return (CGVector(dx: dx, dy: dy), dist < perfectThreshold)
    }

    // MARK: - Scene Alignment Score

    /// Computes a continuous 0.0–1.0 score based on how close the subject is to its ideal position.
    /// Score decreases smoothly as the subject moves away from the target.
    /// Returns 0.0 when no usable scene data is available.
    static func computeSceneAlignmentScore(
        for composition: CompositionType,
        geometry: SceneGeometry,
        isPerfect: Bool,
        depthData: AVDepthData? = nil
    ) -> Float {
        switch composition {

        case .horizontal:
            guard geometry.horizonAngle != 0 else { return 0.0 }
            let angleDeg = abs(geometry.horizonAngle)
            // Smooth score: 1.0 at 0°, decays to 0 at ±15°
            return Float(max(0.0, 1.0 - (angleDeg / 15.0)))

        case .ruleOfThirds, .center, .diagonal, .vertical:
            guard let subject = geometry.smoothedSubjectPoint ?? resolveSubjectPoint(from: geometry, depthData: depthData),
                  let target  = targetPoint(for: composition, subject: subject, geometry: geometry)
            else { return 0.0 }

            let dist = distance(subject, target)
            // Max sensible distance is ~0.5 (half the frame). Score decays linearly.
            let score = Float(max(0.0, 1.0 - (dist / 0.5)))
            return score
        }
    }

    // MARK: - Geometry Helpers

    private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Projects `point` onto the line segment from `from` to `to`, clamped to the segment.
    private static func nearestPointOnSegment(from a: CGPoint, to b: CGPoint, point p: CGPoint) -> CGPoint {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let lenSq = ab.x * ab.x + ab.y * ab.y
        guard lenSq > 0 else { return a }
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lenSq))
        return CGPoint(x: a.x + t * ab.x, y: a.y + t * ab.y)
    }
}
