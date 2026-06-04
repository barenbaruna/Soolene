//
//  VisionService.swift
//  Photograph
//
//  Runs Vision analysis on live camera frames with tiered throttling.
//
//  ─────────────────────────────────────────────────────────────────────
//  DESIGN DECISION — Scene-Based vs Gyroscope Detection
//  ─────────────────────────────────────────────────────────────────────
//  Overlay colors (Red/Green/White) are driven entirely by what Vision
//  detects IN THE CAMERA FRAME — the actual objects and scene content —
//  NOT by device orientation or gyroscope data.
//
//  Why? The goal is to guide the user toward framing the SUBJECT correctly,
//  which is a visual/content decision, not a physical device angle decision.
//
//  - VNDetectHorizonRequest   → detects a visual horizon LINE in the scene
//  - VNGenerateAttentionBasedSaliencyImageRequest → locates the main subject
//  - VNDetectRectanglesRequest → detects strong vertical/horizontal structures
//  - VNDetectFaceRectanglesRequest → locates faces as high-priority subjects
//
//  ─────────────────────────────────────────────────────────────────────
//  Throttling Tiers:
//  - Fast   (every frame):    horizon + face detection
//  - Medium (every 8 frames): saliency analysis + rectangles
//  - Slow   (every 60 frames): ML composition classification
//  ─────────────────────────────────────────────────────────────────────
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import CoreGraphics
import CoreML
import UIKit
import Vision

final class VisionService: @unchecked Sendable {

    // MARK: - Callback

    /// Called on the main queue whenever a new analysis result is ready.
    var onAnalysisUpdated: ((CompositionAnalysis) -> Void)?

    // MARK: - Throttling

    private var frameCounter = 0
    private var isAnalyzing = false

    // MARK: - CoreML Model

    private var compositionModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlpackage")
        else { return nil }
        guard let model = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: model)
        else { return nil }
        return visionModel
    }()

    // MARK: - Accumulated State

    private var currentAnalysis = CompositionAnalysis()
    private var wasCompositionPerfect = false

    // MARK: - Coordinate Helper

    /// Converts a Vision normalised rect (origin bottom-left) to UIKit (origin top-left).
    static func visionToUIKit(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: 1.0 - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Main Entry Point

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isAnalyzing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        frameCounter += 1
        isAnalyzing = true

        let counter = frameCounter
        let snapshot = currentAnalysis

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var updated = snapshot
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

            // ── Fast tier (every frame): horizon + face ───────────────────
            self.runFastRequests(handler: handler, geometry: &updated.sceneGeometry)

            // ── Medium tier (every 8 frames): saliency + rectangles ───────
            if counter % 8 == 0 {
                self.runMediumRequests(pixelBuffer: pixelBuffer, geometry: &updated.sceneGeometry)
            }

            // ── Slow tier (every 60 frames): ML classification ────────────
            if counter % 60 == 0 {
                self.runSlowRequests(handler: handler, analysis: &updated)
            }

            // ── Resolve best composition from ML + geometry ───────────────
            let technique = GuidanceEngine.pickBest(
                predictions: updated.mlPredictions,
                geometry: updated.sceneGeometry
            )
            updated.activeTechnique = technique
            updated.detectedComposition = technique.composition

            // ── Compute subject offset (for arrow direction in UI) ─────────
            let offsetResult = self.computeSubjectOffset(
                for: technique.composition,
                geometry: updated.sceneGeometry
            )
            updated.subjectOffset = offsetResult.vector
            updated.isCompositionPerfect = offsetResult.isPerfect

            // ── Compute scene alignment score (drives Red/Green/White) ─────
            updated.sceneAlignmentScore = self.computeSceneAlignmentScore(
                for: technique.composition,
                geometry: updated.sceneGeometry,
                isPerfect: offsetResult.isPerfect
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentAnalysis = updated
                self.onAnalysisUpdated?(updated)
                self.isAnalyzing = false

                // Haptic feedback when composition snaps to perfect
                if updated.isCompositionPerfect, !self.wasCompositionPerfect {
                    HapticManager.success()
                }
                self.wasCompositionPerfect = updated.isCompositionPerfect
            }
        }
    }

    // MARK: - Fast Tier (every frame)

    /// Detects visual horizon in the scene and face rectangles.
    /// NOTE: VNDetectHorizonRequest finds the VISUAL horizon line in the IMAGE —
    ///       this is scene content, not device tilt.
    private func runFastRequests(handler: VNImageRequestHandler, geometry: inout SceneGeometry) {
        let horizonReq = VNDetectHorizonRequest()
        let faceReq    = VNDetectFaceRectanglesRequest()

        try? handler.perform([horizonReq, faceReq])

        if let obs = horizonReq.results?.first {
            // Convert radians to degrees — this is the tilt of the VISUAL horizon line
            geometry.horizonAngle = obs.angle * (180.0 / .pi)
        }

        geometry.faceRect = faceReq.results?.first.map { VisionService.visionToUIKit($0.boundingBox) }
    }

    // MARK: - Medium Tier (every 8 frames)

    /// Detects subject position (saliency + body pose) and vertical structures.
    ///
    /// Subject detection priority:
    ///   1. Body pose torso center (VNDetectHumanBodyPoseRequest) — most accurate for humans
    ///   2. Attention saliency centroid — fallback for all other subjects
    private func runMediumRequests(pixelBuffer: CVPixelBuffer, geometry: inout SceneGeometry) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        // ── Saliency ──────────────────────────────────────────────────────
        let saliencyReq = VNGenerateAttentionBasedSaliencyImageRequest()

        // ── Body Pose (human center of mass) ──────────────────────────────
        // Uses 4 torso keypoints to approximate body center — much more accurate
        // than saliency centroid for human subjects.
        let bodyPoseReq = VNDetectHumanBodyPoseRequest()

        // ── Vertical structure detection ───────────────────────────────────
        // Looks for rectangles that are significantly taller than wide
        // (e.g., columns, doors, trees) — indicates a Vertical composition scene.
        // VNDetectRectanglesRequest aspect ratio = width / height.
        // A tall object: width/height < 0.5 (e.g., 0.3 means 3× taller than wide)
        let rectReq = VNDetectRectanglesRequest()
        rectReq.minimumAspectRatio = 0.1    // At least 1:10 ratio (extremely tall)
        rectReq.maximumAspectRatio = 0.5    // At most 1:2 ratio (2× taller than wide)
        rectReq.minimumConfidence  = 0.6
        rectReq.maximumObservations = 3

        try? handler.perform([saliencyReq, bodyPoseReq, rectReq])

        // ── Process saliency ──────────────────────────────────────────────
        if let obs = saliencyReq.results?.first as? VNSaliencyImageObservation,
           let salientObjects = obs.salientObjects, !salientObjects.isEmpty
        {
            var totalX: CGFloat = 0, totalY: CGFloat = 0
            var unionRect = CGRect.null
            var totalArea: CGFloat = 0

            for obj in salientObjects {
                let r = VisionService.visionToUIKit(obj.boundingBox)
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

        // ── Process body pose ─────────────────────────────────────────────
        // Use torso keypoints: left/right shoulder and left/right hip.
        // Their centroid approximates the human body's center of mass.
        if let bodyObs = bodyPoseReq.results?.first {
            let torsoJoints: [VNHumanBodyPoseObservation.JointName] = [
                .leftShoulder, .rightShoulder, .leftHip, .rightHip
            ]
            var xs: [CGFloat] = []
            var ys: [CGFloat] = []

            for joint in torsoJoints {
                // Only use high-confidence keypoints (>0.5) to avoid jitter
                if let pt = try? bodyObs.recognizedPoint(joint), pt.confidence > 0.5 {
                    xs.append(pt.location.x)
                    // Vision coords: origin bottom-left → flip Y for UIKit (origin top-left)
                    ys.append(1.0 - pt.location.y)
                }
            }

            if xs.count >= 2 {   // Require at least 2 reliable joints
                geometry.bodyCenter = CGPoint(
                    x: xs.reduce(0, +) / CGFloat(xs.count),
                    y: ys.reduce(0, +) / CGFloat(ys.count)
                )
            } else {
                geometry.bodyCenter = nil
            }
        }

        // ── Process vertical rectangles ───────────────────────────────────
        if let rects = rectReq.results as? [VNRectangleObservation] {
            // Double-check: bounding box height must be > width * 1.5
            let hasVertical = rects.contains { obs in
                let b = obs.boundingBox
                return b.height > b.width * 1.5
            }
            geometry.hasStrongVerticals = hasVertical
        }
    }


    // MARK: - Slow Tier (every 60 frames)

    private func runSlowRequests(handler: VNImageRequestHandler, analysis: inout CompositionAnalysis) {
        guard let cModel = compositionModel else { return }

        let mlReq = VNCoreMLRequest(model: cModel)
        mlReq.imageCropAndScaleOption = .centerCrop
        try? handler.perform([mlReq])

        guard let results = mlReq.results as? [VNClassificationObservation] else { return }

        var predictions: [CompositionPrediction] = []
        for obs in results.prefix(5) {
            if let type = CompositionType(coreMLLabel: obs.identifier) {
                predictions.append(CompositionPrediction(type: type, confidence: obs.confidence))
            }
            if predictions.count >= 3 { break }
        }
        analysis.mlPredictions = predictions
    }

    // MARK: - Scene Alignment Score

    /// Computes a 0.0–1.0 score representing how well the scene content
    /// matches the chosen composition.
    ///
    /// 0.0   = no Vision data available → UI shows WHITE lines
    /// 0–0.8 = data present, not aligned → UI shows RED lines  
    /// 0.8+  = aligned → UI shows GREEN lines
    ///
    /// Crucially: this uses VISUAL/CONTENT detection (saliency, horizon line,
    /// rectangle shapes), NOT device gyroscope or orientation sensors.
    private func computeSceneAlignmentScore(
        for composition: CompositionType,
        geometry: SceneGeometry,
        isPerfect: Bool
    ) -> Float {
        switch composition {

        case .ruleOfThirds, .center, .diagonal:
            // Subject must be detected via any method in the priority chain
            let hasSubject = geometry.faceRect != nil
                          || geometry.bodyCenter != nil
                          || geometry.saliencyCentroid != nil
            guard hasSubject else { return 0.0 }
            return isPerfect ? 0.95 : 0.4

        case .horizontal:
            // Need a VISUAL horizon line in the scene (e.g., ocean, landscape, table edge).
            // VNDetectHorizonRequest returns angle=0 when no horizon is found.
            // A near-zero angle means the visual horizon IS present AND level.
            guard geometry.horizonAngle != 0 else { return 0.0 }  // No visual horizon detected
            let angleDeg = abs(geometry.horizonAngle)
            if angleDeg < 2.0  { return 0.95 }  // Horizon detected and level → GREEN
            if angleDeg < 8.0  { return 0.5  }  // Horizon detected but tilted → RED
            return 0.3                            // Severely tilted horizon → RED

        case .vertical:
            // Need saliency/body data or strong vertical shapes in the scene
            let hasSubject = geometry.bodyCenter != nil || geometry.saliencyBounds != nil
            guard hasSubject || geometry.hasStrongVerticals else { return 0.0 }
            if geometry.hasStrongVerticals { return isPerfect ? 0.95 : 0.55 }
            // Check if saliency bounding box is tall and narrow (vertical subject)
            if let bounds = geometry.saliencyBounds {
                let isVerticalSubject = bounds.height > bounds.width * 1.3
                if isVerticalSubject { return isPerfect ? 0.9 : 0.5 }
            }
            return 0.35
        }
    }

    // MARK: - Subject Offset Computation

    /// Returns the direction vector FROM the subject TO its ideal target position,
    /// and whether the subject is close enough to be considered "perfect".
    ///
    /// Subject detection uses a 3-level priority chain:
    ///   1. Face centroid (VNDetectFaceRectanglesRequest) — highest accuracy for portraits
    ///   2. Body center (VNDetectHumanBodyPoseRequest torso) — accurate for full-body shots
    ///   3. Saliency centroid — fallback for non-human subjects
    private func computeSubjectOffset(
        for composition: CompositionType,
        geometry: SceneGeometry
    ) -> (vector: CGVector, isPerfect: Bool) {

        // Priority chain: face > body > saliency
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
            // Find which intersection point is nearest to the subject
            let targetX: CGFloat = pt.x < 0.5 ? 0.33 : 0.67
            let targetY: CGFloat = pt.y < 0.5 ? 0.33 : 0.67
            dx = targetX - pt.x  // Positive = move right, negative = move left
            dy = targetY - pt.y  // Positive = move down, negative = move up

        case .center:
            dx = 0.5 - pt.x
            dy = 0.5 - pt.y

        case .horizontal:
            // For horizontal, we guide the VISUAL HORIZON alignment,
            // not the subject position. Offset is used just for isPerfect.
            dx = 0
            dy = 0.5 - pt.y

        case .vertical:
            dx = 0.5 - pt.x
            dy = 0

        case .diagonal:
            // Find nearest point on either diagonal line
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
