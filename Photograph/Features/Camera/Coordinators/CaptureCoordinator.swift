//
//  CaptureCoordinator.swift
//  Photograph
//
//  Owns capture readiness gates, execution, and unified error surfacing.
//

import ARKit
import AVFoundation

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

    func isCaptureReady(cameraMode: CameraMode, guidancePhase: GuidancePhase) -> Bool {
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.isSessionConfigured
                && spatialEngine.trackingState == .normal
                && !isCapturing(cameraMode: cameraMode)
        case .frontClassic:
            cameraManager.isSessionRunning && !isCapturing(cameraMode: cameraMode)
        }
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
        }

        visionService.resumeAfterCapture()
    }

    var activeCapturedPhotoData: Data? {
        spatialEngine.capturedPhotoData ?? cameraManager.capturedPhotoData
    }
}
