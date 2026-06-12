//
//  VisionService.swift
//  Photograph
//
//  Coordinates spatial and classic Vision pipelines with shared analysis finalization.
//

import AVFoundation
import CoreGraphics
import CoreML
import Vision

final class VisionService: @unchecked Sendable {

    var onAnalysisUpdated: ((CompositionAnalysis) -> Void)?
    var onMLSuggestionReady: (([CompositionPrediction]) -> Void)?

    var isFrontCamera = false
    var usesSpatialTracking = true
    var isMLEnabled = true
    var deviceRollDegrees: Double?

    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?

    private let analysisLock = NSLock()
    private var frameCounter = 0
    private var isAnalyzing = false
    private var isPausedForCapture = false

    private let saliencySmoother = SaliencySmoother()
    private var analysisProcessor = VisionAnalysisProcessor(
        usesSpatialTracking: true,
        isMLEnabled: true,
        userGuidanceActive: false,
        deviceRollDegrees: nil
    )

    private var compositionModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlpackage")
        else { return nil }
        guard let model = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: model)
        else { return nil }
        return visionModel
    }()

    private var currentAnalysis = CompositionAnalysis()
    private var lastSpatialSubjectPoint: CGPoint?
    private var guidanceGeneration: UInt64 = 0
    private var userGuidanceActive = false

    // MARK: - Subject Pinning

    func pinSubject(at normalisedPoint: CGPoint) {
        bumpGuidanceGeneration()
        userGuidanceActive = false
        syncProcessorContext()

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

    func syncGuidanceState(lockedTarget: CGPoint?, detectedComposition: CompositionType) {
        bumpGuidanceGeneration()
        userGuidanceActive = true
        currentAnalysis.sceneGeometry.lockedTargetPoint = lockedTarget
        currentAnalysis.detectedComposition = detectedComposition
    }

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
        analysisProcessor.resetFilters()
        resetScanningState()
    }

    func resolvedPinPoint(for tap: CGPoint, geometry: SceneGeometry) -> CGPoint {
        guard isFrontCamera, !geometry.faceRects.isEmpty else { return tap }
        let largest = geometry.faceRects.max(by: { $0.width * $0.height < $1.width * $1.height })
        guard let face = largest else { return tap }
        let faceCenter = CGPoint(x: face.midX, y: face.midY)
        let distance = hypot(tap.x - faceCenter.x, tap.y - faceCenter.y)
        return distance < 0.2 ? faceCenter : tap
    }

    // MARK: - Capture Gating

    func shouldProcessVisionFrame() -> Bool {
        analysisLock.lock()
        defer { analysisLock.unlock() }
        return !isAnalyzing && !isPausedForCapture
    }

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
        currentAnalysis.mlPredictions = []
        analysisProcessor.resetHysteresis()
        analysisLock.unlock()
    }

    // MARK: - Spatial Pipeline

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
            SpatialVisionPipeline.applySpatialSubjectPoint(
                spatialSubjectPoint,
                lastStored: &self.lastSpatialSubjectPoint,
                to: &updated
            )

            SpatialVisionPipeline.runVisionRequests(
                pixelBuffer: pixelBuffer,
                orientation: orientation,
                isFrontCamera: self.isFrontCamera,
                frameCounter: counter,
                usesSpatialTracking: self.usesSpatialTracking,
                compositionModel: self.compositionModel,
                isMLEnabled: self.isMLEnabled,
                analysis: &updated
            ) { predictions in
                DispatchQueue.main.async {
                    self.onMLSuggestionReady?(predictions)
                }
            }

            updated.sceneGeometry.saliencyCentroid = self.saliencySmoother.smooth(updated.sceneGeometry.saliencyCentroid)

            if processingGeneration != self.guidanceGeneration {
                updated.sceneGeometry.lockedTargetPoint = self.currentAnalysis.sceneGeometry.lockedTargetPoint
                updated.detectedComposition = self.currentAnalysis.detectedComposition
            }

            let final = self.finalize(updated, depthData: nil)
            self.publishAnalysis(final, processingGeneration: processingGeneration)
        }
    }

    private func publishSpatialProjectionOnly(_ spatialSubjectPoint: CGPoint?) {
        syncProcessorContext()
        let updated = SpatialVisionPipeline.projectionOnlyAnalysis(
            from: currentAnalysis,
            spatialSubjectPoint: spatialSubjectPoint,
            lastSpatialSubjectPoint: &lastSpatialSubjectPoint,
            deviceRollDegrees: deviceRollDegrees
        )
        publishAnalysis(updated, clearsAnalyzingFlag: false)
    }

    // MARK: - Classic Pipeline

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

            ClassicVisionPipeline.runVisionRequests(
                pixelBuffer: pixelBuffer,
                orientation: orientation,
                isFrontCamera: self.isFrontCamera,
                frameCounter: counter,
                compositionModel: self.compositionModel,
                isMLEnabled: self.isMLEnabled,
                sequenceHandler: self.sequenceHandler,
                trackingRequest: &self.trackingRequest,
                analysis: &updated
            ) { predictions in
                DispatchQueue.main.async {
                    self.onMLSuggestionReady?(predictions)
                }
            }

            updated.sceneGeometry.saliencyCentroid = self.saliencySmoother.smooth(updated.sceneGeometry.saliencyCentroid)
            let final = self.finalize(updated, depthData: depthData)
            self.publishAnalysis(final)
        }
    }

    // MARK: - Shared Finalization

    private func finalize(_ input: CompositionAnalysis, depthData: AVDepthData?) -> CompositionAnalysis {
        syncProcessorContext()
        return analysisProcessor.buildFinalAnalysis(from: input, depthData: depthData)
    }

    private func syncProcessorContext() {
        analysisProcessor.usesSpatialTracking = usesSpatialTracking
        analysisProcessor.isMLEnabled = isMLEnabled
        analysisProcessor.userGuidanceActive = userGuidanceActive
        analysisProcessor.deviceRollDegrees = deviceRollDegrees
    }

    private func bumpGuidanceGeneration() {
        analysisLock.lock()
        guidanceGeneration &+= 1
        analysisLock.unlock()
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
        }
    }
}
