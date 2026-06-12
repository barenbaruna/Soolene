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

    /// Hardware/session gates for capture (matches `integration/ui-logic-sync`).
    /// Composition perfection is reflected in `shutterReadiness`, not this gate.
    func isCaptureReady(cameraMode: CameraMode, guidancePhase _: GuidancePhase) -> Bool {
        guard !isCapturing(cameraMode: cameraMode) else { return false }

        switch cameraMode {
        case .rearSpatial:
            return spatialEngine.isSessionConfigured
                && spatialEngine.trackingState == .normal
        case .frontClassic:
            return cameraManager.isSessionRunning
        }
    }

    func shutterReadiness(
        cameraMode: CameraMode,
        guidancePhase: GuidancePhase,
        isCompositionPerfect: Bool
    ) -> ShutterReadiness {
        let hardwareReady = isCaptureReady(cameraMode: cameraMode, guidancePhase: guidancePhase)
        if guidancePhase.isPerfect && hardwareReady { return .ready }
        if guidancePhase.isPerfect || isCompositionPerfect { return .stabilizing }
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
            if !cameraManager.isCapturingPhoto, cameraManager.capturedPhotoData != nil {
                return
            }
            if !cameraManager.isCapturingPhoto, cameraManager.captureError != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    var activeCapturedPhotoData: Data? {
        spatialEngine.capturedPhotoData ?? cameraManager.capturedPhotoData
    }
}
