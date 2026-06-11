//
//  GeometryExtractor.swift
//  Photograph
//
//  Converts raw Vision observations into our SceneGeometry domain model.
//  Handles coordinate system differences between Vision (bottom-left origin)
//  and UIKit (top-left origin), including front camera X-axis mirroring.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreGraphics
import Vision

struct GeometryExtractor {

    // MARK: - Fast Tier

    static func extractFastTier(
        horizonObs: VNHorizonObservation?,
        faces: [VNFaceObservation]?,
        isFrontCamera: Bool,
        into geometry: inout SceneGeometry
    ) {
        if let obs = horizonObs {
            geometry.horizonAngle = obs.angle * (180.0 / .pi)
            geometry.horizonDetected = true
        } else {
            geometry.horizonDetected = false
        }

        if let faces = faces {
            geometry.faceRects = faces.map { visionToUIKit($0.boundingBox, isFrontCamera: isFrontCamera) }
        } else {
            geometry.faceRects = []
        }
    }

    // MARK: - Medium Tier

    static func extractSaliency(
        obs: VNSaliencyImageObservation?,
        isFrontCamera: Bool,
        into geometry: inout SceneGeometry
    ) {
        guard let salientObjects = obs?.salientObjects, !salientObjects.isEmpty else {
            geometry.saliencyCentroid = nil
            geometry.saliencyBounds = nil
            return
        }

        var totalX: CGFloat = 0, totalY: CGFloat = 0
        var unionRect = CGRect.null
        var totalArea: CGFloat = 0

        for obj in salientObjects {
            let r = visionToUIKit(obj.boundingBox, isFrontCamera: isFrontCamera)
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

    static func extractObjectness(
        obs: VNSaliencyImageObservation?,
        isFrontCamera: Bool,
        into geometry: inout SceneGeometry
    ) {
        guard let salientObjects = obs?.salientObjects, !salientObjects.isEmpty else {
            geometry.objectnessCentroid = nil
            return
        }

        var totalX: CGFloat = 0, totalY: CGFloat = 0

        for obj in salientObjects {
            let r = visionToUIKit(obj.boundingBox, isFrontCamera: isFrontCamera)
            totalX += r.midX
            totalY += r.midY
        }

        let count = CGFloat(salientObjects.count)
        geometry.objectnessCentroid = CGPoint(x: totalX / count, y: totalY / count)
    }

    static func extractBodyPose(
        obs: VNHumanBodyPoseObservation?,
        isFrontCamera: Bool,
        into geometry: inout SceneGeometry
    ) {
        guard let bodyObs = obs else {
            geometry.bodyCenter = nil
            return
        }

        let torsoJoints: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder, .leftHip, .rightHip
        ]
        var xs: [CGFloat] = []
        var ys: [CGFloat] = []

        for joint in torsoJoints {
            if let pt = try? bodyObs.recognizedPoint(joint), pt.confidence > 0.5 {
                // Vision body pose: origin bottom-left, Y up — flip Y to UIKit
                let uiX = isFrontCamera ? (1.0 - pt.location.x) : pt.location.x
                let uiY = 1.0 - pt.location.y
                xs.append(uiX)
                ys.append(uiY)
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

    // MARK: - Coordinate Conversion

    /// Converts a Vision normalised rect (origin: bottom-left) to UIKit space (origin: top-left).
    /// When isFrontCamera is true, flips X to match the mirrored preview layer.
    static func visionToUIKit(_ rect: CGRect, isFrontCamera: Bool) -> CGRect {
        let x = isFrontCamera ? (1.0 - rect.origin.x - rect.width) : rect.origin.x
        let y = 1.0 - rect.origin.y - rect.height
        return CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }
}
