//
//  CameraSessionCoordinator.swift
//  Photograph
//
//  Serializes rear/front camera handoff and session lifecycle.
//

import AVFoundation
import OSLog

@MainActor
final class CameraSessionCoordinator {

    private static let handoffLog = Logger(
        subsystem: "com.barenbaruna.Photograph",
        category: "CaptureHandoff"
    )

    private let spatialEngine: SpatialCameraEngine
    private let cameraManager: CameraManager
    private let visionService: VisionService

    var onGuidanceReset: (() -> Void)?
    var onPreviewReady: (() -> Void)?

    init(
        spatialEngine: SpatialCameraEngine,
        cameraManager: CameraManager,
        visionService: VisionService
    ) {
        self.spatialEngine = spatialEngine
        self.cameraManager = cameraManager
        self.visionService = visionService
    }

    func switchToFrontClassic(hasCameraPermission: Bool, checkPermissions: () async -> Void) async {
        await spatialEngine.stopSessionAndWait()
        spatialEngine.clearSubjectAnchor()
        onGuidanceReset?()

        visionService.usesSpatialTracking = false
        visionService.isFrontCamera = true
        visionService.isMLEnabled = false
        // Clear stale rear-camera scene data (saliency, faces) so front camera
        // grid overlays don't inherit a "nearest intersection" from the previous session.
        visionService.clearSceneData()

        if !hasCameraPermission {
            await checkPermissions()
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let lock = NSLock()
            var resumed = false

            func resumeOnce() {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }

            cameraManager.onPreviewFrameReady = { @Sendable in
                Task { @MainActor in
                    resumeOnce()
                }
            }

            cameraManager.sessionQueue.async { [cameraManager] in
                cameraManager.configureSession(useFront: true, displayMultiplier: 1.0)
                cameraManager.startSession()
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                resumeOnce()
            }
        }

        cameraManager.onPreviewFrameReady = nil
        onPreviewReady?()
    }

    func switchToRearSpatial() async {
        await cameraManager.stopSessionAndWait()
        onGuidanceReset?()

        visionService.usesSpatialTracking = true
        visionService.isFrontCamera = false
        visionService.isMLEnabled = true

        await spatialEngine.checkPermissionsAndSetup()
    }

    func pauseSessions(cameraMode: CameraMode) {
        spatialEngine.stopSession()
        cameraManager.stopSession()
    }

    func resumeSession(cameraMode: CameraMode) {
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.resumeSessionPreservingAnchors()
        case .frontClassic:
            cameraManager.startSession()
        }
    }

    /// AR → AV → AR when rear hi-res capture fails (Option F default mode).
    func captureRearViaAVFallback(snapshot: CaptureHandoffSnapshot) async -> CaptureHandoffResult {
        await performRearAVHandoff(snapshot: snapshot, telemetryPath: .avFallback)
    }

    /// AR → AV → AR for E-lite zoomed capture (display multiplier ≠ 1×).
    func captureRearViaZoomedHandoff(snapshot: CaptureHandoffSnapshot) async -> CaptureHandoffResult {
        await performRearAVHandoff(snapshot: snapshot, telemetryPath: .avZoomed)
    }

    private func performRearAVHandoff(
        snapshot: CaptureHandoffSnapshot,
        telemetryPath: CaptureTelemetry.CapturePath
    ) async -> CaptureHandoffResult {
        let start = CFAbsoluteTimeGetCurrent()
        let usedWorldMap = snapshot.worldMap != nil

        Self.handoffLog.info(
            "Handoff start path=\(telemetryPath.rawValue) worldMap=\(usedWorldMap)"
        )

        let pauseStart = CFAbsoluteTimeGetCurrent()
        await spatialEngine.pauseForHandoff()
        CaptureTelemetry.recordHandoffStage(
            path: telemetryPath,
            stage: "arPause",
            elapsedMs: Self.elapsedMs(since: pauseStart)
        )

        cameraManager.captureError = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturedImage = nil

        let prepareStart = CFAbsoluteTimeGetCurrent()
        await cameraManager.prepareRearCaptureForHandoff(
            snapshot,
            telemetryPath: telemetryPath
        )
        CaptureTelemetry.recordHandoffStage(
            path: telemetryPath,
            stage: "avPrepare",
            elapsedMs: Self.elapsedMs(since: prepareStart),
            detail: "displayMultiplier=\(String(format: "%.2f", snapshot.cameraControls.displayMultiplier))"
        )

        let captureStart = CFAbsoluteTimeGetCurrent()
        let captureOK = await cameraManager.capturePhotoAndWait(
            aspectRatio: snapshot.aspectRatio,
            telemetryPath: telemetryPath
        )
        CaptureTelemetry.recordHandoffStage(
            path: telemetryPath,
            stage: "avCapture",
            elapsedMs: Self.elapsedMs(since: captureStart),
            success: captureOK,
            detail: "bytes=\(cameraManager.capturedPhotoData?.count ?? 0)"
        )
        let photoData = captureOK ? cameraManager.capturedPhotoData : nil

        let stopStart = CFAbsoluteTimeGetCurrent()
        await cameraManager.stopSessionAndWait()
        CaptureTelemetry.recordHandoffStage(
            path: telemetryPath,
            stage: "avStop",
            elapsedMs: Self.elapsedMs(since: stopStart)
        )

        let resumeStart = CFAbsoluteTimeGetCurrent()
        let resumeResult = await spatialEngine.resumeAfterHandoff(
            snapshot,
            waitsForTrackingRecovery: false,
            telemetryPath: telemetryPath
        )
        CaptureTelemetry.recordHandoffStage(
            path: telemetryPath,
            stage: "arResumeTotal",
            elapsedMs: Self.elapsedMs(since: resumeStart),
            success: resumeResult != .trackingDegraded
        )
        spatialEngine.clearHandoffFrozenPreview()

        let trackingRecovered: Bool
        let recoveryDeferred: Bool
        switch resumeResult {
        case .recoveredWithWorldMap, .recoveredWithoutWorldMap:
            trackingRecovered = true
            recoveryDeferred = false
        case .recoveryDeferred:
            trackingRecovered = false
            recoveryDeferred = true
        case .trackingDegraded:
            trackingRecovered = false
            recoveryDeferred = false
        }

        visionService.usesSpatialTracking = true
        visionService.isFrontCamera = false
        visionService.isMLEnabled = true

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let elapsedMs = Int(elapsed * 1000)
        Self.handoffLog.info(
            "Handoff complete path=\(telemetryPath.rawValue) success=\(photoData != nil) trackingRecovered=\(trackingRecovered) elapsed=\(String(format: "%.2f", elapsed))s"
        )

        CaptureTelemetry.recordHandoffComplete(
            path: telemetryPath,
            success: photoData != nil,
            usedWorldMap: usedWorldMap,
            trackingRecovered: trackingRecovered,
            recoveryDeferred: recoveryDeferred,
            elapsedMs: elapsedMs,
            frozenPreviewMs: elapsedMs
        )

        return CaptureHandoffResult(
            photoData: photoData,
            trackingRecovered: trackingRecovered,
            recoveryDeferred: recoveryDeferred,
            usedWorldMap: usedWorldMap,
            elapsedSeconds: elapsed
        )
    }

    private static func elapsedMs(since start: CFAbsoluteTime) -> Int {
        Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    }
}
