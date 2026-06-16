//
//  SpatialVisionPipeline.swift
//  Photograph
//

import CoreGraphics
import Vision

/// Vision request scheduling for ARKit spatial frame packets.
enum SpatialVisionPipeline {

    static func runVisionRequests(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        isFrontCamera: Bool,
        frameCounter: Int,
        usesSpatialTracking: Bool,
        compositionModel: VNCoreMLModel?,
        isMLEnabled: Bool,
        analysis: inout CompositionAnalysis,
        onMLPredictions: @escaping ([CompositionPrediction]) -> Void
    ) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        VisionRequestManager.runFastRequests(handler: handler, geometry: &analysis.sceneGeometry, isFrontCamera: isFrontCamera)

        let saliencyInterval = usesSpatialTracking ? 15 : 8
        if frameCounter % saliencyInterval == 0 {
            VisionRequestManager.runMediumRequests(handler: handler, geometry: &analysis.sceneGeometry, isFrontCamera: isFrontCamera)
        }

        if frameCounter % 60 == 0, let model = compositionModel, isMLEnabled {
            VisionRequestManager.runSlowRequests(handler: handler, model: model, analysis: &analysis)
            onMLPredictions(analysis.mlPredictions)
        }
    }

    static func projectionOnlyAnalysis(
        from current: CompositionAnalysis,
        spatialSubjectPoint: CGPoint?,
        lastSpatialSubjectPoint: inout CGPoint?,
        deviceRollDegrees: Double?
    ) -> CompositionAnalysis {
        var updated = current
        updated.sceneGeometry.deviceRollDegrees = deviceRollDegrees
        applySpatialSubjectPoint(spatialSubjectPoint, lastStored: &lastSpatialSubjectPoint, to: &updated)

        if updated.sceneGeometry.isSubjectLocked {
            if let tracked = updated.sceneGeometry.trackedSubjectPoint {
                updated.sceneGeometry.smoothedSubjectPoint = tracked
            }
            let offsetResult = AlignmentAnalyzer.computeSubjectOffset(
                for: updated.detectedComposition,
                geometry: updated.sceneGeometry,
                wasPerfect: current.isCompositionPerfect
            )
            updated.subjectOffset = offsetResult.vector
            updated.isCompositionPerfect = offsetResult.isPerfect
            updated.guidanceDistance = offsetResult.guidanceDistance
            updated.sceneAlignmentScore = AlignmentAnalyzer.computeSceneAlignmentScore(
                for: updated.detectedComposition,
                geometry: updated.sceneGeometry,
                isPerfect: offsetResult.isPerfect
            )
        }
        return updated
    }

    static func applySpatialSubjectPoint(
        _ spatialSubjectPoint: CGPoint?,
        lastStored: inout CGPoint?,
        to updated: inout CompositionAnalysis
    ) {
        guard updated.sceneGeometry.isSubjectLocked else { return }

        if let spatial = spatialSubjectPoint {
            lastStored = spatial
            updated.sceneGeometry.applyTrackedProjection(spatial)
        } else if let last = lastStored {
            updated.sceneGeometry.applyTrackedProjection(last)
        }
    }
}
