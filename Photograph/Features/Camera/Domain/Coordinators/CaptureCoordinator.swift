//
//  CaptureCoordinator.swift
//  Photograph
//

import ARKit
import AVFoundation
import UIKit

/// Capture readiness gates, execution, and unified error surfacing.
@MainActor
final class CaptureCoordinator {

    private let spatialEngine: SpatialCameraEngine
    private let cameraManager: CameraManager
    private let visionService: VisionService
    private let sessionCoordinator: CameraSessionCoordinator

    init(
        spatialEngine: SpatialCameraEngine,
        cameraManager: CameraManager,
        visionService: VisionService,
        sessionCoordinator: CameraSessionCoordinator
    ) {
        self.spatialEngine = spatialEngine
        self.cameraManager = cameraManager
        self.visionService = visionService
        self.sessionCoordinator = sessionCoordinator
    }

    /// True during the full AR ↔ AV ↔ AR handoff (blocks duplicate shutter taps).
    var isCaptureHandoffInProgress = false

    /// True while AR tracking is re-stabilizing after an AV fallback capture.
    var isHandoffRecovering = false

    /// Hardware/session gates for capture (tracking stable on rear spatial).
    func isHardwareCaptureReady(cameraMode: CameraMode) -> Bool {
        guard !isCapturing(cameraMode: cameraMode),
              !isCaptureHandoffInProgress,
              !isHandoffRecovering else { return false }

        switch cameraMode {
        case .rearSpatial:
            return spatialEngine.isSessionConfigured
                && spatialEngine.trackingState == .normal
                && spatialEngine.trackingStabilityProgress >= 1.0
        case .frontClassic:
            return cameraManager.isSessionRunning
        }
    }

    /// Single source of truth for all capture-related UI.
    func captureReadiness(
        cameraMode: CameraMode,
        guidancePhase: GuidancePhase,
        analysis: CompositionAnalysis
    ) -> CaptureReadiness {
        if isHandoffRecovering {
            return .handoffRecovering
        }
        if isCaptureHandoffInProgress {
            return .capturing
        }
        if isCapturing(cameraMode: cameraMode) {
            return .capturing
        }

        let hardwareReady = isHardwareCaptureReady(cameraMode: cameraMode)
        let compositionAligned = guidancePhase.isPerfect || analysis.isCompositionPerfect

        switch guidancePhase {
        case .scanning:
            return .scanning
        case .subjectLocked:
            return .subjectLocked
        case .guiding(let composition):
            if compositionAligned {
                return hardwareReady
                    ? .captureReady(composition: composition)
                    : .compositionReady(composition: composition)
            }
            let progress = alignmentProgress(from: analysis)
            return .aligning(composition: composition, progress: progress)
        case .perfect(let composition):
            return hardwareReady
                ? .captureReady(composition: composition)
                : .compositionReady(composition: composition)
        }
    }

    private func alignmentProgress(from analysis: CompositionAnalysis) -> Float {
        let normalized = Float(min(max(analysis.guidanceDistance / 0.12, 0), 1))
        return max(analysis.sceneAlignmentScore, 1 - normalized)
    }

    /// Clears post-handoff recovery once tracking is stable. Call from tracking observers — not from readiness reads.
    func clearHandoffRecoveryIfTrackingStable(
        trackingState: ARCamera.TrackingState,
        stabilityProgress: Float
    ) {
        guard isHandoffRecovering else { return }
        if trackingState == .normal, stabilityProgress >= 1.0 {
            isHandoffRecovering = false
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

    func clearCapturedPhotoData() {
        spatialEngine.capturedPhotoData = nil
        spatialEngine.capturedImage = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturedImage = nil
    }

    func executeCapture(
        cameraMode: CameraMode,
        aspectRatio: AspectRatioMode,
        guidancePhase: GuidancePhase,
        analysis: CompositionAnalysis
    ) async {
        let readiness = captureReadiness(
            cameraMode: cameraMode,
            guidancePhase: guidancePhase,
            analysis: analysis
        )
        guard readiness.isShutterEnabled, !isCapturing(cameraMode: cameraMode) else { return }

        clearCaptureErrors()
        await visionService.prepareForCapture()

        let captureMode = telemetryMode(for: cameraMode)
        let shutterStart = CFAbsoluteTimeGetCurrent()
        CaptureTelemetry.recordShutterAttempt(mode: captureMode)

        switch cameraMode {
        case .rearSpatial:
            await runDefaultRearCapture(
                aspectRatio: aspectRatio,
                captureMode: captureMode,
                shutterStart: shutterStart
            )
        case .frontClassic:
            cameraManager.capturePhoto(aspectRatio: aspectRatio)
            await waitForClassicCaptureCompletion()
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - shutterStart) * 1000)
            logCaptureComplete(
                mode: .frontClassic,
                path: .av,
                success: cameraManager.capturedPhotoData != nil,
                latencyMs: latencyMs,
                photoData: cameraManager.capturedPhotoData
            )
        }

        visionService.resumeAfterCapture()
    }

    private func telemetryMode(for cameraMode: CameraMode) -> CaptureTelemetry.CaptureMode {
        switch cameraMode {
        case .frontClassic:
            return .frontClassic
        case .rearSpatial:
            return .default
        }
    }

    private func logCaptureComplete(
        mode: CaptureTelemetry.CaptureMode,
        path: CaptureTelemetry.CapturePath,
        success: Bool,
        latencyMs: Int,
        photoData: Data?
    ) {
        var dimensions: String?
        var bytes: Int?
        if let photoData {
            bytes = photoData.count
            if let image = UIImage(data: photoData) {
                dimensions = "\(Int(image.size.width))x\(Int(image.size.height))"
            }
        }
        CaptureTelemetry.recordCaptureComplete(
            mode: mode,
            path: path,
            success: success,
            latencyMs: latencyMs,
            bytes: bytes,
            dimensions: dimensions,
            thermal: ProcessInfo.processInfo.thermalState.rawValue
        )
    }

    private func runDefaultRearCapture(
        aspectRatio: AspectRatioMode,
        captureMode: CaptureTelemetry.CaptureMode,
        shutterStart: CFAbsoluteTime
    ) async {
        let displayMultiplier = spatialEngine.displayMultiplier

        if CaptureZoomRouting.shouldUseZoomedAVHandoff(
            displayMultiplier: displayMultiplier,
            elLiteEnabled: CaptureArchitectureFlags.elLiteCaptureEnabled
        ) {
            CaptureTelemetry.recordCaptureRoute(
                displayMultiplier: displayMultiplier,
                route: "avZoomed"
            )
            await runRearAVHandoff(
                aspectRatio: aspectRatio,
                shutterStart: shutterStart,
                telemetryMode: captureMode,
                telemetryPath: .avZoomed
            ) { snapshot in
                await sessionCoordinator.captureRearViaZoomedHandoff(snapshot: snapshot)
            }
            return
        }

        CaptureTelemetry.recordCaptureRoute(
            displayMultiplier: displayMultiplier,
            route: "arHiRes"
        )
        await spatialEngine.captureHighResolutionPhoto(aspectRatio: aspectRatio)
        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - shutterStart) * 1000)
        if let data = spatialEngine.capturedPhotoData {
            logCaptureComplete(
                mode: captureMode,
                path: .ar,
                success: true,
                latencyMs: latencyMs,
                photoData: data
            )
        } else if CaptureArchitectureFlags.avFallbackEnabled {
            CaptureTelemetry.recordCaptureComplete(
                mode: captureMode,
                path: .ar,
                success: false,
                latencyMs: latencyMs,
                arErrorCode: spatialEngine.lastCaptureARErrorCode,
                thermal: ProcessInfo.processInfo.thermalState.rawValue
            )
            await runRearAVHandoff(
                aspectRatio: aspectRatio,
                shutterStart: shutterStart,
                telemetryMode: .default,
                telemetryPath: .avFallback
            ) { snapshot in
                await sessionCoordinator.captureRearViaAVFallback(snapshot: snapshot)
            }
        } else {
            CaptureTelemetry.recordCaptureComplete(
                mode: captureMode,
                path: .ar,
                success: false,
                latencyMs: latencyMs,
                arErrorCode: spatialEngine.lastCaptureARErrorCode,
                thermal: ProcessInfo.processInfo.thermalState.rawValue
            )
        }
    }

    private func runRearAVHandoff(
        aspectRatio: AspectRatioMode,
        shutterStart: CFAbsoluteTime,
        telemetryMode: CaptureTelemetry.CaptureMode,
        telemetryPath: CaptureTelemetry.CapturePath,
        handoff: (CaptureHandoffSnapshot) async -> CaptureHandoffResult
    ) async {
        isCaptureHandoffInProgress = true
        defer { isCaptureHandoffInProgress = false }

        let snapshot = await spatialEngine.makeHandoffSnapshot(aspectRatio: aspectRatio)
        let result = await handoff(snapshot)

        if let data = result.photoData {
            applyHandoffPhotoData(data)
            let totalLatencyMs = Int((CFAbsoluteTimeGetCurrent() - shutterStart) * 1000)
            logCaptureComplete(
                mode: telemetryMode,
                path: telemetryPath,
                success: true,
                latencyMs: totalLatencyMs,
                photoData: data
            )
        } else {
            let totalLatencyMs = Int((CFAbsoluteTimeGetCurrent() - shutterStart) * 1000)
            logCaptureComplete(
                mode: telemetryMode,
                path: telemetryPath,
                success: false,
                latencyMs: totalLatencyMs,
                photoData: nil
            )
        }

        isHandoffRecovering = !result.trackingRecovered
    }

    private func applyHandoffPhotoData(_ data: Data) {
        spatialEngine.capturedPhotoData = data
        spatialEngine.capturedImage = UIImage(data: data)
        spatialEngine.captureError = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturedImage = nil
        cameraManager.captureError = nil
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
