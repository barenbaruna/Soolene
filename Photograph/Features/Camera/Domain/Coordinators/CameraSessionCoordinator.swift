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
        visionService.isMLEnabled = true

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

    private func performRearAVHandoff(
        snapshot: CaptureHandoffSnapshot,
        telemetryPath: CaptureTelemetry.CapturePath
    ) async -> CaptureHandoffResult {
        let start = CFAbsoluteTimeGetCurrent()
        let usedWorldMap = snapshot.worldMap != nil

        Self.handoffLog.info(
            "Handoff start path=\(telemetryPath.rawValue) worldMap=\(usedWorldMap)"
        )

        await spatialEngine.pauseForHandoff()

        cameraManager.captureError = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturedImage = nil

        await cameraManager.prepareRearCaptureForHandoff(snapshot)

        let captureOK = await cameraManager.capturePhotoAndWait(aspectRatio: snapshot.aspectRatio)
        let photoData = captureOK ? cameraManager.capturedPhotoData : nil

        await cameraManager.stopSessionAndWait()

        let resumeResult = await spatialEngine.resumeAfterHandoff(snapshot)
        spatialEngine.clearHandoffFrozenPreview()

        let trackingRecovered: Bool
        switch resumeResult {
        case .recoveredWithWorldMap, .recoveredWithoutWorldMap:
            trackingRecovered = true
        case .trackingDegraded:
            trackingRecovered = false
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
            elapsedMs: elapsedMs,
            frozenPreviewMs: elapsedMs
        )

        return CaptureHandoffResult(
            photoData: photoData,
            trackingRecovered: trackingRecovered,
            usedWorldMap: usedWorldMap,
            elapsedSeconds: elapsed
        )
    }
}
