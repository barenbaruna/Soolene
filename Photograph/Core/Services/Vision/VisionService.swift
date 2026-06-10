//
//  VisionService.swift
//  Photograph
//
//  Runs Vision analysis on live camera frames with tiered throttling.
//
//  This service acts purely as a coordinator.
//  - VisionRequestManager handles the VNRequests
//  - GeometryExtractor parses the results
//  - AlignmentAnalyzer computes the math
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import CoreGraphics
import CoreML
import Vision

final class VisionService: @unchecked Sendable {
    
    // MARK: - Callback
    
    /// Called on the main queue whenever a new analysis result is ready.
    var onAnalysisUpdated: ((CompositionAnalysis) -> Void)?
    
    // MARK: - Camera Context

    /// Must be kept in sync with CameraManager.isUsingFrontCamera.
    /// When true, Vision observations have their X-axis flipped to match the mirrored preview.
    var isFrontCamera: Bool = false

    // MARK: - Subject Pinning

    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?

    /// Locks the subject at a user-tapped point (normalised 0–1 UIKit coords) and begins ML tracking.
    func pinSubject(at normalisedPoint: CGPoint) {
        // Create an initial bounding box (15% of screen size) to feed into the ML tracker
        let boxSize: CGFloat = 0.15
        let rect = CGRect(
            x: max(0, normalisedPoint.x - boxSize/2),
            y: max(0, normalisedPoint.y - boxSize/2),
            width: min(1, boxSize),
            height: min(1, boxSize)
        )
        
        let observation = VNDetectedObjectObservation(boundingBox: rect)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .fast
        
        self.trackingRequest = request
        currentAnalysis.sceneGeometry.userPinnedSubject = normalisedPoint
        currentAnalysis.sceneGeometry.lockedTargetPoint = nil // Reset lock on new user input
    }

    /// Clears the pinned subject and stops tracking, restoring Vision auto-detection.
    func clearPinnedSubject() {
        trackingRequest = nil
        currentAnalysis.sceneGeometry.userPinnedSubject = nil
        currentAnalysis.sceneGeometry.lockedTargetPoint = nil
    }

    // MARK: - ML Gating

    /// When false, the slow-tier ML classification is skipped.
    /// Set to false after the user selects a composition to prevent chaotic switching.
    var isMLEnabled: Bool = true

    /// Called on the main queue when a one-shot ML prediction completes.
    var onMLSuggestionReady: (([CompositionPrediction]) -> Void)?

    // MARK: - Throttling
    
    private var frameCounter = 0
    private var isAnalyzing = false
    
    // MARK: - Filters
    
    private let oneEuroFilter = OneEuroPointFilter()
    private let saliencySmoother = SaliencySmoother()
    
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
    
    // MARK: - CoreML Model
    
    func processFrame(_ sampleBuffer: CMSampleBuffer, depthData: AVDepthData? = nil) {
        guard !isAnalyzing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        frameCounter += 1
        isAnalyzing = true
        
        let counter = frameCounter
        let snapshot = currentAnalysis
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            var updated = snapshot
            // Preserve user-pinned subject across frames — it is set externally via pinSubject()
            updated.sceneGeometry.userPinnedSubject = self.currentAnalysis.sceneGeometry.userPinnedSubject
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: isFrontCamera ? .leftMirrored : .right, options: [:])
            
            // Execute Object Tracking if user tapped the screen
            if let tracker = self.trackingRequest {
                do {
                    try self.sequenceHandler.perform([tracker], on: pixelBuffer, orientation: isFrontCamera ? .leftMirrored : .right)
                    if let result = tracker.results?.first as? VNDetectedObjectObservation {
                        let newCenter = CGPoint(x: result.boundingBox.midX, y: result.boundingBox.midY)
                        updated.sceneGeometry.userPinnedSubject = newCenter
                        
                        // Update tracker for next frame
                        let nextRequest = VNTrackObjectRequest(detectedObjectObservation: result)
                        nextRequest.trackingLevel = .fast
                        self.trackingRequest = nextRequest
                    } else {
                        // Tracking lost
                        self.trackingRequest = nil
                        updated.sceneGeometry.userPinnedSubject = nil
                    }
                } catch {
                    self.trackingRequest = nil
                    updated.sceneGeometry.userPinnedSubject = nil
                }
            }
            
            // Fast tier (every frame): horizon + face
            VisionRequestManager.runFastRequests(handler: handler, geometry: &updated.sceneGeometry, isFrontCamera: isFrontCamera)
            
            // Medium tier (every 8 frames): saliency + rectangles
            if counter % 8 == 0 {
                VisionRequestManager.runMediumRequests(handler: handler, geometry: &updated.sceneGeometry, isFrontCamera: isFrontCamera)
            }
            
            // Slow tier (every 60 frames): ML classification — only when enabled
            if counter % 60 == 0, let model = self.compositionModel, self.isMLEnabled {
                VisionRequestManager.runSlowRequests(handler: handler, model: model, analysis: &updated)
            }
            
            // Apply Smoothing to Saliency
            updated.sceneGeometry.saliencyCentroid = self.saliencySmoother.smooth(updated.sceneGeometry.saliencyCentroid)
            
            // Resolve raw subject and apply 1-Euro Filter for 60fps tracking
            if let rawSubject = AlignmentAnalyzer.resolveSubjectPoint(from: updated.sceneGeometry, depthData: depthData) {
                let smoothedSubject = self.oneEuroFilter.filter(rawSubject)
                updated.sceneGeometry.smoothedSubjectPoint = smoothedSubject
                
                var unlockedGeometry = updated.sceneGeometry
                unlockedGeometry.lockedTargetPoint = nil // Ensure fresh calculation
                if let newTarget = AlignmentAnalyzer.targetPoint(for: updated.detectedComposition, subject: smoothedSubject, geometry: unlockedGeometry) {
                    updated.sceneGeometry.lockedTargetPoint = newTarget
                }
            } else {
                self.oneEuroFilter.reset()
                updated.sceneGeometry.smoothedSubjectPoint = nil
            }
            
            // Resolve best composition from ML predictions.
            // GuidanceEngine returns nil until the model produces its first result (~2s).
            if let technique = GuidanceEngine.pickBest(
                predictions: updated.mlPredictions,
                geometry: updated.sceneGeometry
            ) {
                if technique.composition != updated.detectedComposition {
                    updated.sceneGeometry.lockedTargetPoint = nil
                }
                updated.activeTechnique = technique
                updated.detectedComposition = technique.composition
            }
            
            // Compute subject offset using the smoothed subject position.
            let offsetResult = AlignmentAnalyzer.computeSubjectOffset(
                for: updated.detectedComposition,
                geometry: updated.sceneGeometry,
                depthData: depthData
            )
            updated.subjectOffset = offsetResult.vector
            updated.isCompositionPerfect = offsetResult.isPerfect
            updated.guidanceDistance = hypot(offsetResult.vector.dx, offsetResult.vector.dy)

            // Compute scene alignment score
            updated.sceneAlignmentScore = AlignmentAnalyzer.computeSceneAlignmentScore(
                for: updated.detectedComposition,
                geometry: updated.sceneGeometry,
                isPerfect: offsetResult.isPerfect,
                depthData: depthData
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
}
