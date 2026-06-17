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
    var onMLSuggestionReady: ((UInt64, [CompositionPrediction]) -> Void)?

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
    private(set) var guidanceGeneration: UInt64 = 0
    private var immediateInferencePending = false
    private var userGuidanceActive = false

    /// Initial Vision tracking box size (normalized). Smaller box reduces drift to bbox center mass.
    private static let classicTrackingBoxSize: CGFloat = 0.08

    // MARK: - Subject Pinning

    func pinSubject(at normalisedPoint: CGPoint) {
        bumpGuidanceGeneration()
        userGuidanceActive = false
        syncProcessorContext()

        currentAnalysis.sceneGeometry.establishUserLock(at: normalisedPoint)
        currentAnalysis.sceneGeometry.lockedTargetPoint = nil
        currentAnalysis.mlPredictions = []
        immediateInferencePending = true

        if usesSpatialTracking {
            trackingRequest = nil
            return
        }

        let boxSize = Self.classicTrackingBoxSize
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
        currentAnalysis.sceneGeometry.clearUserLock()
        currentAnalysis.sceneGeometry.lockedTargetPoint = nil
        currentAnalysis.detectedComposition = .ruleOfThirds
        currentAnalysis.mlPredictions = []
        analysisProcessor.resetFilters()
        resetScanningState()
    }

    func resolvedPinPoint(for tap: CGPoint, geometry: SceneGeometry) -> CGPoint {
        guard isFrontCamera, !geometry.faceRects.isEmpty else { return tap }

        var nearestFace: CGRect?
        var nearestDistance: CGFloat = .infinity

        for face in geometry.faceRects {
            let faceCenter = CGPoint(x: face.midX, y: face.midY)
            let distance = hypot(tap.x - faceCenter.x, tap.y - faceCenter.y)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestFace = face
            }
        }

        guard let face = nearestFace, nearestDistance < 0.2 else { return tap }
        return CGPoint(x: face.midX, y: face.midY)
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

        let deadline = Date().addingTimeInterval(0.15)
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
        let forceInference = immediateInferencePending
        immediateInferencePending = false
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
                forceInference: forceInference,
                analysis: &updated
            ) { predictions in
                DispatchQueue.main.async {
                    self.onMLSuggestionReady?(processingGeneration, predictions)
                }
            }

            updated.sceneGeometry.saliencyCentroid = self.saliencySmoother.smooth(updated.sceneGeometry.saliencyCentroid)

            if processingGeneration != self.guidanceGeneration {
                updated.sceneGeometry.lockedTargetPoint = self.currentAnalysis.sceneGeometry.lockedTargetPoint
                updated.detectedComposition = self.currentAnalysis.detectedComposition
                self.copyLockState(from: self.currentAnalysis.sceneGeometry, to: &updated.sceneGeometry)
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

        analysisLock.lock()
        let processingGeneration = guidanceGeneration
        let forceInference = immediateInferencePending
        immediateInferencePending = false
        analysisLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var updated = snapshot
            self.copyLockState(from: self.currentAnalysis.sceneGeometry, to: &updated.sceneGeometry)

            ClassicVisionPipeline.runVisionRequests(
                pixelBuffer: pixelBuffer,
                orientation: orientation,
                isFrontCamera: self.isFrontCamera,
                frameCounter: counter,
                compositionModel: self.compositionModel,
                isMLEnabled: self.isMLEnabled,
                forceInference: forceInference,
                sequenceHandler: self.sequenceHandler,
                trackingRequest: &self.trackingRequest,
                analysis: &updated
            ) { predictions in
                DispatchQueue.main.async {
                    self.onMLSuggestionReady?(processingGeneration, predictions)
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

    private func copyLockState(from source: SceneGeometry, to destination: inout SceneGeometry) {
        destination.userLockOrigin = source.userLockOrigin
        destination.trackedSubjectPoint = source.trackedSubjectPoint
        destination.subjectTrackingOffset = source.subjectTrackingOffset
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
                self.copyLockState(from: self.currentAnalysis.sceneGeometry, to: &merged.sceneGeometry)
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
