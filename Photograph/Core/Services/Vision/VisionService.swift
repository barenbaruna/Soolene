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

    /// When true, Vision observations have their X-axis flipped to match the mirrored preview.
    var isFrontCamera: Bool = false

    /// When true, subject position comes from ARKit anchor projection (not VNTrackObjectRequest).
    var usesSpatialTracking: Bool = true

    // MARK: - Subject Pinning

    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?

    /// Locks the subject at a user-tapped point (normalised 0–1 UIKit coords).
    /// With spatial tracking, ARKit owns world lock; Vision only stores the seed point.
    func pinSubject(at normalisedPoint: CGPoint) {
        bumpGuidanceGeneration()
        userGuidanceActive = false
        if usesSpatialTracking {
            trackingRequest = nil
            currentAnalysis.sceneGeometry.userPinnedSubject = normalisedPoint
            currentAnalysis.sceneGeometry.lockedTargetPoint = nil
            return
        }

        let boxSize: CGFloat = 0.15
        let rect = CGRect(
            x: max(0, normalisedPoint.x - boxSize / 2),
            y: max(0, normalisedPoint.y - boxSize / 2),
            width: min(1, boxSize),
            height: min(1, boxSize)
        )

        let observation = VNDetectedObjectObservation(boundingBox: rect)
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .fast

        trackingRequest = request
        currentAnalysis.sceneGeometry.userPinnedSubject = normalisedPoint
        currentAnalysis.sceneGeometry.lockedTargetPoint = nil
    }

    /// Syncs composition state from the view model into the vision accumulator.
    func syncGuidanceState(
        lockedTarget: CGPoint?,
        detectedComposition: CompositionType
    ) {
        bumpGuidanceGeneration()
        userGuidanceActive = true
        currentAnalysis.sceneGeometry.lockedTargetPoint = lockedTarget
        currentAnalysis.detectedComposition = detectedComposition
    }

    /// Clears the pinned subject and stops tracking, restoring Vision auto-detection.
    func clearPinnedSubject() {
        bumpGuidanceGeneration()
        userGuidanceActive = false
        trackingRequest = nil
        lastSpatialSubjectPoint = nil
        currentAnalysis.sceneGeometry.userPinnedSubject = nil
        currentAnalysis.sceneGeometry.lockedTargetPoint = nil
        currentAnalysis.sceneGeometry.smoothedSubjectPoint = nil
        currentAnalysis.detectedComposition = .ruleOfThirds
        currentAnalysis.mlPredictions = []
        scanningFilter.reset()
        guidanceFilter.reset()
        resetScanningState()
    }

    /// Snaps a tap to the largest detected face center when on the front camera.
    func resolvedPinPoint(for tap: CGPoint, geometry: SceneGeometry) -> CGPoint {
        guard isFrontCamera, !geometry.faceRects.isEmpty else { return tap }
        let largest = geometry.faceRects.max(by: { $0.width * $0.height < $1.width * $1.height })
        guard let face = largest else { return tap }
        let faceCenter = CGPoint(x: face.midX, y: face.midY)
        let distance = hypot(tap.x - faceCenter.x, tap.y - faceCenter.y)
        return distance < 0.2 ? faceCenter : tap
    }

    // MARK: - ML Gating

    var isMLEnabled: Bool = true
    var onMLSuggestionReady: (([CompositionPrediction]) -> Void)?

    // MARK: - Throttling

    private let analysisLock = NSLock()
    private var frameCounter = 0
    private var isAnalyzing = false
    private var isPausedForCapture = false

    // ML hysteresis (scanning only)
    private var hysteresisComposition: CompositionType?
    private var hysteresisConfidence: Float = 0
    private var hysteresisFrameCount = 0

    /// Called from the ARSession delegate before copying a pixel buffer.
    func shouldProcessVisionFrame() -> Bool {
        analysisLock.lock()
        defer { analysisLock.unlock() }
        return !isAnalyzing && !isPausedForCapture
    }

    /// Pauses Vision buffer processing and waits for any in-flight analysis to finish.
    func prepareForCapture() async {
        analysisLock.lock()
        isPausedForCapture = true
        analysisLock.unlock()

        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            analysisLock.lock()
            let busy = isAnalyzing
            analysisLock.unlock()
            if !busy { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func resumeAfterCapture() {
        analysisLock.lock()
        isPausedForCapture = false
        analysisLock.unlock()
    }

    func resetScanningState() {
        analysisLock.lock()
        frameCounter = 0
        hysteresisComposition = nil
        hysteresisConfidence = 0
        hysteresisFrameCount = 0
        currentAnalysis.mlPredictions = []
        analysisLock.unlock()
    }

    // MARK: - Filters

    private let scanningFilter = OneEuroPointFilter(minCutoff: 0.8, beta: 0.005)
    private let guidanceFilter = OneEuroPointFilter(minCutoff: 0.1, beta: 0.001)

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
    private var lastSpatialSubjectPoint: CGPoint?
    private var guidanceGeneration: UInt64 = 0
    private var userGuidanceActive = false

    /// Device roll in degrees from CoreMotion — fused into horizontal guidance.
    var deviceRollDegrees: Double?

    private func bumpGuidanceGeneration() {
        analysisLock.lock()
        guidanceGeneration &+= 1
        analysisLock.unlock()
    }

    // MARK: - AR Frame Pipeline

    /// Processes a spatial packet. AR-projected subject updates every frame; Vision runs when a buffer is present.
    func processSpatialFramePacket(_ packet: SpatialFramePacket) {
        let spatialSubjectPoint = packet.spatialSubjectPoint

        if packet.pixelBuffer == nil {
            publishSpatialProjectionOnly(spatialSubjectPoint)
            return
        }

        analysisLock.lock()
        guard !isAnalyzing else {
            analysisLock.unlock()
            publishSpatialProjectionOnly(spatialSubjectPoint)
            return
        }
        isAnalyzing = true
        analysisLock.unlock()

        frameCounter += 1

        let counter = frameCounter
        let snapshot = currentAnalysis
        let pixelBuffer = packet.pixelBuffer!
        let orientation = CoordinateMapper.visionOrientation(isFrontCamera: isFrontCamera)
        let lockedTarget = snapshot.sceneGeometry.lockedTargetPoint
        analysisLock.lock()
        let processingGeneration = guidanceGeneration
        analysisLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var updated = snapshot
            updated.sceneGeometry.lockedTargetPoint = lockedTarget
            updated.sceneGeometry.deviceRollDegrees = self.deviceRollDegrees
            self.applySpatialSubjectPoint(spatialSubjectPoint, to: &updated)

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

            VisionRequestManager.runFastRequests(handler: handler, geometry: &updated.sceneGeometry, isFrontCamera: isFrontCamera)

            // Saliency sparingly (~every 15 frames) during spatial tracking.
            let saliencyInterval = self.usesSpatialTracking ? 15 : 8
            if counter % saliencyInterval == 0 {
                VisionRequestManager.runMediumRequests(handler: handler, geometry: &updated.sceneGeometry, isFrontCamera: isFrontCamera)
            }

            // FiveCompositionDetector: Rule of Thirds, Center, Diagonal, Horizontal, Vertical
            if counter % 60 == 0, let model = self.compositionModel, self.isMLEnabled {
                VisionRequestManager.runSlowRequests(handler: handler, model: model, analysis: &updated)
                let predictions = updated.mlPredictions
                DispatchQueue.main.async {
                    self.onMLSuggestionReady?(predictions)
                }
            }

            updated.sceneGeometry.saliencyCentroid = self.saliencySmoother.smooth(updated.sceneGeometry.saliencyCentroid)

            if processingGeneration != self.guidanceGeneration {
                updated.sceneGeometry.lockedTargetPoint = self.currentAnalysis.sceneGeometry.lockedTargetPoint
                updated.detectedComposition = self.currentAnalysis.detectedComposition
            }

            let final = self.buildFinalAnalysis(from: updated, depthData: nil)
            self.publishAnalysis(final, processingGeneration: processingGeneration)
        }
    }

    private func applySpatialSubjectPoint(_ spatialSubjectPoint: CGPoint?, to updated: inout CompositionAnalysis) {
        if let spatial = spatialSubjectPoint {
            lastSpatialSubjectPoint = spatial
            updated.sceneGeometry.userPinnedSubject = spatial
        } else if let last = lastSpatialSubjectPoint, updated.sceneGeometry.userPinnedSubject != nil {
            updated.sceneGeometry.userPinnedSubject = last
        }
    }

    /// Lightweight path: refresh AR-projected subject without running Vision (no buffer copy).
    private func publishSpatialProjectionOnly(_ spatialSubjectPoint: CGPoint?) {
        var updated = currentAnalysis
        updated.sceneGeometry.deviceRollDegrees = deviceRollDegrees
        applySpatialSubjectPoint(spatialSubjectPoint, to: &updated)
        if updated.sceneGeometry.userPinnedSubject != nil {
            updated.sceneGeometry.smoothedSubjectPoint = updated.sceneGeometry.userPinnedSubject
            let offsetResult = AlignmentAnalyzer.computeSubjectOffset(
                for: updated.detectedComposition,
                geometry: updated.sceneGeometry
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
        publishAnalysis(updated, clearsAnalyzingFlag: false)
    }

    // MARK: - Legacy AVFoundation Pipeline

    func processFrame(_ sampleBuffer: CMSampleBuffer, depthData: AVDepthData? = nil) {
        guard !usesSpatialTracking else { return }
        analysisLock.lock()
        guard !isAnalyzing, !isPausedForCapture else {
            analysisLock.unlock()
            return
        }
        isAnalyzing = true
        analysisLock.unlock()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            analysisLock.lock()
            isAnalyzing = false
            analysisLock.unlock()
            return
        }

        frameCounter += 1

        let counter = frameCounter
        let snapshot = currentAnalysis
        let orientation = CoordinateMapper.visionOrientation(isFrontCamera: isFrontCamera)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var updated = snapshot
            updated.sceneGeometry.userPinnedSubject = self.currentAnalysis.sceneGeometry.userPinnedSubject
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

            if let tracker = self.trackingRequest {
                do {
                    try self.sequenceHandler.perform([tracker], on: pixelBuffer, orientation: orientation)
                    if let result = tracker.results?.first as? VNDetectedObjectObservation {
                        let uiRect = GeometryExtractor.visionToUIKit(result.boundingBox, isFrontCamera: isFrontCamera)
                        let newCenter = CGPoint(x: uiRect.midX, y: uiRect.midY)

                        let meetsConfidence = result.confidence > 0.3
                        var meetsVelocity = true
                        if let lastPos = updated.sceneGeometry.userPinnedSubject {
                            let jump = hypot(newCenter.x - lastPos.x, newCenter.y - lastPos.y)
                            if jump > 0.15 { meetsVelocity = false }
                        }

                        if meetsConfidence && meetsVelocity {
                            updated.sceneGeometry.userPinnedSubject = newCenter
                        }

                        let nextRequest = VNTrackObjectRequest(detectedObjectObservation: result)
                        nextRequest.trackingLevel = .fast
                        self.trackingRequest = nextRequest
                    } else {
                        self.trackingRequest = nil
                        updated.sceneGeometry.userPinnedSubject = nil
                    }
                } catch {
                    self.trackingRequest = nil
                    updated.sceneGeometry.userPinnedSubject = nil
                }
            }

            VisionRequestManager.runFastRequests(handler: handler, geometry: &updated.sceneGeometry, isFrontCamera: isFrontCamera)

            if counter % 8 == 0 {
                VisionRequestManager.runMediumRequests(handler: handler, geometry: &updated.sceneGeometry, isFrontCamera: isFrontCamera)
            }

            if counter % 60 == 0, let model = self.compositionModel, self.isMLEnabled {
                VisionRequestManager.runSlowRequests(handler: handler, model: model, analysis: &updated)
                let predictions = updated.mlPredictions
                DispatchQueue.main.async {
                    self.onMLSuggestionReady?(predictions)
                }
            }

            updated.sceneGeometry.saliencyCentroid = self.saliencySmoother.smooth(updated.sceneGeometry.saliencyCentroid)

            let final = self.buildFinalAnalysis(from: updated, depthData: depthData)
            self.publishAnalysis(final)
        }
    }

    // MARK: - Shared Finalization

    private func buildFinalAnalysis(from input: CompositionAnalysis, depthData: AVDepthData?) -> CompositionAnalysis {
        var updated = input
        updated.sceneGeometry.deviceRollDegrees = deviceRollDegrees

        if let rawSubject = AlignmentAnalyzer.resolveSubjectPoint(from: updated.sceneGeometry, depthData: depthData) {
            let smoothedSubject: CGPoint
            if usesSpatialTracking, updated.sceneGeometry.lockedTargetPoint != nil {
                // ARKit projection is already stable — avoid One Euro lag during guidance.
                smoothedSubject = rawSubject
            } else {
                let activeFilter = (updated.sceneGeometry.lockedTargetPoint != nil) ? guidanceFilter : scanningFilter
                smoothedSubject = activeFilter.filter(rawSubject)
            }
            updated.sceneGeometry.smoothedSubjectPoint = smoothedSubject

            if updated.sceneGeometry.lockedTargetPoint == nil, !userGuidanceActive {
                if let newTarget = AlignmentAnalyzer.targetPoint(
                    for: updated.detectedComposition,
                    subject: smoothedSubject,
                    geometry: updated.sceneGeometry
                ) {
                    updated.sceneGeometry.lockedTargetPoint = newTarget
                }
            }
        } else {
            scanningFilter.reset()
            guidanceFilter.reset()
            updated.sceneGeometry.smoothedSubjectPoint = nil
        }

        if isMLEnabled, !userGuidanceActive, !updated.mlPredictions.isEmpty {
            let composition = applyMLHysteresis(
                predictions: updated.mlPredictions,
                current: updated.detectedComposition
            )
            if composition != updated.detectedComposition {
                updated.sceneGeometry.lockedTargetPoint = nil
            }
            updated.detectedComposition = composition
            if let technique = GuidanceEngine.pickBest(
                predictions: updated.mlPredictions,
                geometry: updated.sceneGeometry
            ) {
                updated.activeTechnique = CompositionTechnique(
                    composition: composition,
                    tip: technique.tip
                )
            }
        }

        let offsetResult = AlignmentAnalyzer.computeSubjectOffset(
            for: updated.detectedComposition,
            geometry: updated.sceneGeometry,
            depthData: depthData
        )
        updated.subjectOffset = offsetResult.vector
        updated.isCompositionPerfect = offsetResult.isPerfect
        updated.guidanceDistance = offsetResult.guidanceDistance

        updated.sceneAlignmentScore = AlignmentAnalyzer.computeSceneAlignmentScore(
            for: updated.detectedComposition,
            geometry: updated.sceneGeometry,
            isPerfect: offsetResult.isPerfect,
            depthData: depthData
        )

        return updated
    }

    private func applyMLHysteresis(
        predictions: [CompositionPrediction],
        current: CompositionType
    ) -> CompositionType {
        guard let top = predictions.first else { return current }

        if top.type == current || top.type == hysteresisComposition {
            hysteresisFrameCount = 0
            hysteresisComposition = top.type
            hysteresisConfidence = top.confidence
            return top.type
        }

        let delta = top.confidence - hysteresisConfidence
        if hysteresisComposition == nil || delta >= GuidanceEngine.mlHysteresisMinDelta {
            hysteresisComposition = top.type
            hysteresisConfidence = top.confidence
            hysteresisFrameCount = 0
            return top.type
        }

        hysteresisFrameCount += 1
        if hysteresisFrameCount >= GuidanceEngine.mlHysteresisFrames {
            hysteresisComposition = top.type
            hysteresisConfidence = top.confidence
            hysteresisFrameCount = 0
            return top.type
        }

        return hysteresisComposition ?? current
    }

    private func publishAnalysis(
        _ updated: CompositionAnalysis,
        clearsAnalyzingFlag: Bool = true,
        processingGeneration: UInt64? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var merged = updated
            if let processingGeneration, processingGeneration != self.guidanceGeneration {
                merged.sceneGeometry.lockedTargetPoint = self.currentAnalysis.sceneGeometry.lockedTargetPoint
                merged.detectedComposition = self.currentAnalysis.detectedComposition
            }
            self.currentAnalysis = merged
            self.onAnalysisUpdated?(merged)

            if clearsAnalyzingFlag {
                self.analysisLock.lock()
                self.isAnalyzing = false
                self.analysisLock.unlock()
            }

            if merged.isCompositionPerfect, !self.wasCompositionPerfect {
                HapticManager.success()
            }
            self.wasCompositionPerfect = merged.isCompositionPerfect
        }
    }
}
