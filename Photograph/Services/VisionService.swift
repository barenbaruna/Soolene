//
//  VisionService.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import CoreGraphics
import CoreML
import UIKit
import Vision

/// Runs Vision analysis on video frames with tiered throttling.
/// - Fast tier (every frame): horizon + face detection
/// - Medium tier (every 8 frames): saliency analysis
/// - Slow tier (every 60 frames): composition ML prediction
final class VisionService: @unchecked Sendable {

    // MARK: - Callbacks

    var onAnalysisUpdated: ((CompositionAnalysis) -> Void)?

    // MARK: - Throttling

    private var frameCounter = 0
    private var isAnalyzing = false

    // MARK: - CoreML Model

    private var compositionModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlmodelc") ??
            Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlpackage")
        else {
            return nil
        }
        guard let model = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: model) else { return nil }
        return visionModel
    }()

    // MARK: - Accumulated State

    private var currentAnalysis = CompositionAnalysis()
    private var wasCompositionPerfect = false

    // MARK: - Coordinate Helpers

    /// Converts Vision rect (origin bottom-left) to UIKit (origin top-left).
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
        let analysis = currentAnalysis

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var updated = analysis
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

            // --- Fast Tier: every frame ---
            self.runFastRequests(handler: handler, geometry: &updated.sceneGeometry)

            // --- Medium Tier: every 8 frames ---
            if counter % 8 == 0 {
                self.runMediumRequests(pixelBuffer: pixelBuffer, geometry: &updated.sceneGeometry)
            }

            // --- Slow Tier: every 60 frames ---
            if counter % 60 == 0 {
                self.runSlowRequests(handler: handler, analysis: &updated)
            }

            // Refresh guidance recommendation
            let technique = GuidanceEngine.pickBest(
                predictions: updated.mlPredictions,
                geometry: updated.sceneGeometry
            )
            updated.activeTechnique = technique
            updated.detectedComposition = technique.composition

            // Compute subject offset for UI feedback
            let offset = self.computeOffset(
                for: technique.composition,
                geometry: updated.sceneGeometry
            )
            updated.subjectOffset = offset.vector
            updated.isCompositionPerfect = offset.isPerfect

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentAnalysis = updated
                self.onAnalysisUpdated?(updated)
                self.isAnalyzing = false
                
                // Trigger success haptic if we just became perfect
                if updated.isCompositionPerfect && !self.wasCompositionPerfect {
                    HapticManager.success()
                }
                self.wasCompositionPerfect = updated.isCompositionPerfect
            }
        }
    }

    // MARK: - Fast Tier (every frame)

    private func runFastRequests(handler: VNImageRequestHandler, geometry: inout SceneGeometry) {
        let horizonReq = VNDetectHorizonRequest()
        let faceReq = VNDetectFaceRectanglesRequest()

        try? handler.perform([horizonReq, faceReq])

        if let horizonObs = horizonReq.results?.first {
            geometry.horizonAngle = horizonObs.angle * (180.0 / .pi)
        }

        if let face = faceReq.results?.first {
            geometry.faceRect = VisionService.visionToUIKit(face.boundingBox)
        } else {
            geometry.faceRect = nil
        }
    }

    // MARK: - Medium Tier (every 8 frames)

    private func runMediumRequests(pixelBuffer: CVPixelBuffer, geometry: inout SceneGeometry) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        let saliencyReq = VNGenerateAttentionBasedSaliencyImageRequest()

        try? handler.perform([saliencyReq])

        if let saliencyObs = saliencyReq.results?.first as? VNSaliencyImageObservation,
           let salientObjects = saliencyObs.salientObjects, !salientObjects.isEmpty
        {
            var totalX: CGFloat = 0, totalY: CGFloat = 0
            var unionRect = CGRect.null
            var totalArea: CGFloat = 0

            for obj in salientObjects {
                let uiRect = VisionService.visionToUIKit(obj.boundingBox)
                totalX += uiRect.midX
                totalY += uiRect.midY
                unionRect = unionRect.union(uiRect)
                totalArea += uiRect.width * uiRect.height
            }

            let count = CGFloat(salientObjects.count)
            geometry.saliencyCentroid = CGPoint(x: totalX / count, y: totalY / count)
            geometry.saliencyBounds = unionRect
            geometry.saliencyAreaRatio = min(totalArea, 1.0)
        }
    }

    // MARK: - Slow Tier (every 60 frames)

    private func runSlowRequests(handler: VNImageRequestHandler, analysis: inout CompositionAnalysis) {
        guard let cModel = compositionModel else { return }

        let mlReq = VNCoreMLRequest(model: cModel)
        mlReq.imageCropAndScaleOption = .centerCrop
        try? handler.perform([mlReq])

        guard let results = mlReq.results as? [VNClassificationObservation] else { return }

        // Build Top-3 predictions
        var predictions: [CompositionPrediction] = []
        for obs in results.prefix(5) {
            if let type = CompositionType(coreMLLabel: obs.identifier) {
                predictions.append(CompositionPrediction(type: type, confidence: obs.confidence))
            }
            if predictions.count >= 3 { break }
        }

        analysis.mlPredictions = predictions
    }

    // MARK: - Subject Offset Computation

    private func computeOffset(
        for composition: CompositionType,
        geometry: SceneGeometry
    ) -> (vector: CGVector, isPerfect: Bool) {
        // Find subject point (face priority over saliency)
        let subjectPoint: CGPoint?
        if let face = geometry.faceRect {
            subjectPoint = CGPoint(x: face.midX, y: face.midY)
        } else {
            subjectPoint = geometry.saliencyCentroid
        }

        guard let pt = subjectPoint else {
            return (.zero, false)
        }

        var dx: CGFloat = 0
        var dy: CGFloat = 0

        switch composition {
        case .ruleOfThirds:
            let closestX: CGFloat = pt.x < 0.5 ? 0.33 : 0.67
            let closestY: CGFloat = pt.y < 0.5 ? 0.33 : 0.67
            dx = pt.x - closestX
            dy = pt.y - closestY

        case .center:
            dx = pt.x - 0.5
            dy = pt.y - 0.5

        case .horizontal:
            dx = 0
            dy = pt.y - 0.5

        case .vertical:
            dx = pt.x - 0.5
            dy = 0

        case .diagonal:
            // For diagonal, closest point on either diagonal line
            // Line 1: y = x, Line 2: y = 1-x
            let distToDiag1 = abs(pt.y - pt.x) / sqrt(2)
            let distToDiag2 = abs(pt.y - (1 - pt.x)) / sqrt(2)
            let minDist = min(distToDiag1, distToDiag2)
            dx = minDist > 0.08 ? (pt.x - 0.5) : 0
            dy = minDist > 0.08 ? (pt.y - 0.5) : 0
        }

        let dist = hypot(dx, dy)
        let isPerfect = dist < 0.08
        return (CGVector(dx: dx, dy: dy), isPerfect)
    }
}
