//
//  CaptureCoordinator.swift
//  Photograph
//

import ARKit
import AVFoundation

/// Capture readiness gates, execution, and unified error surfacing.
@MainActor
final class CaptureCoordinator {

    private let spatialEngine: SpatialCameraEngine
    private let cameraManager: CameraManager
    private let visionService: VisionService

    init(
        spatialEngine: SpatialCameraEngine,
        cameraManager: CameraManager,
        visionService: VisionService
    ) {
        self.spatialEngine = spatialEngine
        self.cameraManager = cameraManager
        self.visionService = visionService
    }

    /// True when composition is perfect and hardware/session gates pass.
    func isCaptureReady(cameraMode: CameraMode, guidancePhase: GuidancePhase) -> Bool {
        guard guidancePhase.isPerfect else { return false }
        guard !isCapturing(cameraMode: cameraMode) else { return false }

        switch cameraMode {
        case .rearSpatial:
            return spatialEngine.isSessionConfigured
                && spatialEngine.trackingState == .normal
                && spatialEngine.trackingStabilityProgress >= 1.0
        case .frontClassic:
            return cameraManager.isSessionRunning
        }
    }

    func shutterReadiness(
        cameraMode: CameraMode,
        guidancePhase: GuidancePhase,
        isCompositionPerfect: Bool
    ) -> ShutterReadiness {
        let captureReady = isCaptureReady(cameraMode: cameraMode, guidancePhase: guidancePhase)
        let aligned = guidancePhase.isPerfect || isCompositionPerfect
        if guidancePhase.isPerfect && captureReady { return .ready }
        if aligned && !captureReady { return .stabilizing }
        return .idle
    }

    func isCapturing(cameraMode: CameraMode) -> Bool {
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.isCapturingHighResolution
        case .frontClassic:
            cameraManager.isCapturingPhoto
        }
    }

    var activeCaptureError: String? {
        spatialEngine.captureError ?? cameraManager.captureError
    }

    func clearCaptureErrors() {
        spatialEngine.captureError = nil
        cameraManager.captureError = nil
    }

    func clearCapturedPhotoData() {
        spatialEngine.capturedPhotoData = nil
        spatialEngine.capturedImage = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturedImage = nil
    }

    func executeCapture(
        cameraMode: CameraMode,
        aspectRatio: AspectRatioMode,
        isCaptureReady: Bool
    ) async {
        guard isCaptureReady, !isCapturing(cameraMode: cameraMode) else { return }

        clearCaptureErrors()
        await visionService.prepareForCapture()

        switch cameraMode {
        case .rearSpatial:
            await spatialEngine.captureHighResolutionPhoto(aspectRatio: aspectRatio)
        case .frontClassic:
            cameraManager.capturePhoto(aspectRatio: aspectRatio)
            await waitForClassicCaptureCompletion()
        }

        visionService.resumeAfterCapture()
    }

    private func waitForClassicCaptureCompletion(timeout: TimeInterval = 12) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !cameraManager.isCapturingPhoto {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    var activeCapturedPhotoData: Data? {
        spatialEngine.capturedPhotoData ?? cameraManager.capturedPhotoData
    }
}
