//
//  ClassicVisionPipeline.swift
//  Photograph
//

import AVFoundation
import CoreGraphics
import Vision

/// Vision request scheduling for AVFoundation sample buffers (front camera).
enum ClassicVisionPipeline {

    static func runVisionRequests(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        isFrontCamera: Bool,
        frameCounter: Int,
        compositionModel: VNCoreMLModel?,
        isMLEnabled: Bool,
        forceInference: Bool,
        sequenceHandler: VNSequenceRequestHandler,
        trackingRequest: inout VNTrackObjectRequest?,
        analysis: inout CompositionAnalysis,
        onMLPredictions: @escaping ([CompositionPrediction]) -> Void
    ) {
        if let tracker = trackingRequest {
            do {
                try sequenceHandler.perform([tracker], on: pixelBuffer, orientation: orientation)
                if let result = tracker.results?.first as? VNDetectedObjectObservation {
                    let uiRect = GeometryExtractor.visionToUIKit(result.boundingBox, isFrontCamera: isFrontCamera)
                    let boxCenter = CGPoint(x: uiRect.midX, y: uiRect.midY)

                    let meetsConfidence = result.confidence > 0.3
                    var meetsVelocity = true
                    if let lastPos = analysis.sceneGeometry.trackedSubjectPoint
                                  ?? analysis.sceneGeometry.userLockOrigin {
                        let jump = hypot(boxCenter.x - lastPos.x, boxCenter.y - lastPos.y)
                        if jump > 0.15 { meetsVelocity = false }
                    }

                    if meetsConfidence && meetsVelocity {
                        analysis.sceneGeometry.applyTrackedProjection(boxCenter)
                    }

                    let nextRequest = VNTrackObjectRequest(detectedObjectObservation: result)
                    nextRequest.trackingLevel = .fast
                    trackingRequest = nextRequest
                } else {
                    trackingRequest = nil
                    analysis.sceneGeometry.clearUserLock()
                }
            } catch {
                trackingRequest = nil
                analysis.sceneGeometry.clearUserLock()
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        VisionRequestManager.runFastRequests(handler: handler, geometry: &analysis.sceneGeometry, isFrontCamera: isFrontCamera)

        if frameCounter % 8 == 0 {
            VisionRequestManager.runMediumRequests(handler: handler, geometry: &analysis.sceneGeometry, isFrontCamera: isFrontCamera)
        }

        if (forceInference || frameCounter % 60 == 0), let model = compositionModel, isMLEnabled {
            VisionRequestManager.runSlowRequests(handler: handler, model: model, analysis: &analysis)
            onMLPredictions(analysis.mlPredictions)
        }
    }
}
