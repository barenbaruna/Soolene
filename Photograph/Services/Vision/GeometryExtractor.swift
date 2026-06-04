//
//  GeometryExtractor.swift
//  Photograph
//
//  Converts raw Vision observations into our simple SceneGeometry domain model.
//  This keeps the Vision Service clean and focused.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreGraphics
import Vision

struct GeometryExtractor {
    
    // MARK: - Fast Tier
    
    static func extractFastTier(
        horizonObs: VNHorizonObservation?,
        faceObs: VNFaceObservation?,
        into geometry: inout SceneGeometry
    ) {
        if let obs = horizonObs {
            geometry.horizonAngle = obs.angle * (180.0 / .pi)
        }
        
        geometry.faceRect = faceObs.map { visionToUIKit($0.boundingBox) }
    }
    
    // MARK: - Medium Tier
    
    static func extractSaliency(
        obs: VNSaliencyImageObservation?,
        into geometry: inout SceneGeometry
    ) {
        guard let salientObjects = obs?.salientObjects, !salientObjects.isEmpty else { return }
        
        var totalX: CGFloat = 0, totalY: CGFloat = 0
        var unionRect = CGRect.null
        var totalArea: CGFloat = 0

        for obj in salientObjects {
            let r = visionToUIKit(obj.boundingBox)
            totalX += r.midX
            totalY += r.midY
            unionRect = unionRect.union(r)
            totalArea += r.width * r.height
        }

        let count = CGFloat(salientObjects.count)
        geometry.saliencyCentroid = CGPoint(x: totalX / count, y: totalY / count)
        geometry.saliencyBounds   = unionRect
        geometry.saliencyAreaRatio = min(totalArea, 1.0)
    }
    
    static func extractBodyPose(
        obs: VNHumanBodyPoseObservation?,
        into geometry: inout SceneGeometry
    ) {
        guard let bodyObs = obs else { return }
        
        let torsoJoints: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder, .leftHip, .rightHip
        ]
        var xs: [CGFloat] = []
        var ys: [CGFloat] = []

        for joint in torsoJoints {
            if let pt = try? bodyObs.recognizedPoint(joint), pt.confidence > 0.5 {
                xs.append(pt.location.x)
                ys.append(1.0 - pt.location.y) // flip Y
            }
        }

        if xs.count >= 2 {
            geometry.bodyCenter = CGPoint(
                x: xs.reduce(0, +) / CGFloat(xs.count),
                y: ys.reduce(0, +) / CGFloat(ys.count)
            )
        } else {
            geometry.bodyCenter = nil
        }
    }
    
    static func extractRectangles(
        rects: [VNRectangleObservation]?,
        into geometry: inout SceneGeometry
    ) {
        guard let rects = rects else { return }
        
        let hasVertical = rects.contains { obs in
            let b = obs.boundingBox
            return b.height > b.width * 1.5
        }
        geometry.hasStrongVerticals = hasVertical
    }
    
    // MARK: - Coordinate Helper
    
    static func visionToUIKit(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: 1.0 - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
