//
//  CameraViewModel+Capture.swift
//  Photograph
//

import Photos
import SwiftUI
import UIKit

extension CameraViewModel {

    func showInlineToast(_ message: String, duration: TimeInterval = 4) {
        inlineToastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if inlineToastMessage == message {
                inlineToastMessage = nil
            }
        }
    }

    func capturePhoto() {
        if isCapturing {
            showInlineToast("Capture in progress")
            return
        }
        if timerLength > 0 {
            startCountdown()
        } else {
            executeCapture()
        }
    }

    func cancelCountdown() {
        isCountingDown = false
    }

    func savePhoto() async {
        guard let data = activeCapturedPhotoData else { return }

        await refreshPermissions()
        guard photoAddPermission.allowsPhotoSave else {
            let message = PrivacyPermissionService.photoSaveMessage(for: photoAddPermission)
            saveError = message
            showInlineToast(message)
            return
        }

        do {
            try await GalleryManager.shared.savePhoto(data, composition: resolvedComposition)

            if let image = UIImage(data: data) {
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80))
                let thumb = renderer.image { _ in
                    image.draw(in: CGRect(x: 0, y: 0, width: 80, height: 80))
                }
                lastSavedThumbnail = thumb
            }
            captureCoordinator.clearCapturedPhotoData()
        } catch {
            let message = error.localizedDescription
            saveError = message
            showInlineToast(message)
        }
    }

    func clearCaptureError() {
        captureCoordinator.clearCaptureErrors()
    }

    var captureReadiness: CaptureReadiness {
        captureCoordinator.captureReadiness(
            cameraMode: cameraMode,
            guidancePhase: guidancePhase,
            analysis: analysis
        )
    }

    /// Hardware + tracking gate (legacy name — prefer `captureReadiness.isShutterEnabled`).
    var isCaptureReady: Bool {
        captureReadiness.isShutterEnabled
    }

    var shutterIsPerfect: Bool {
        captureReadiness.showsGreenCelebration
    }

    var isStabilizingForCapture: Bool {
        captureReadiness.showsStabilizingUI
    }

    var shutterReadiness: ShutterReadiness {
        captureReadiness.shutterVisual
    }

    var activeCapturedPhotoData: Data? {
        captureCoordinator.activeCapturedPhotoData
    }

    var captureError: String? {
        captureCoordinator.activeCaptureError
    }

    var isCapturing: Bool {
        captureCoordinator.isCapturing(cameraMode: cameraMode)
            || captureCoordinator.isCaptureHandoffInProgress
    }

    var isCaptureHandoffInProgress: Bool {
        captureCoordinator.isCaptureHandoffInProgress
    }

    var isHandoffRecovering: Bool {
        captureCoordinator.isHandoffRecovering
    }

    var handoffFrozenPreviewImage: UIImage? {
        spatialEngine.handoffFrozenPreviewImage
    }

    /// Shown when engineering flag allows Max Quality on rear spatial camera.
    var showsMaxQualityToggle: Bool {
        cameraMode == .rearSpatial && CaptureArchitectureFlags.maxQualityCaptureEnabled
    }

    /// User + flag effective Max Quality Mode (capture path wired in Epic 4b).
    var isMaxQualityCaptureEnabled: Bool {
        captureSettings.maxQualityCaptureActive
    }

    func toggleMaxQualityCapture() {
        guard showsMaxQualityToggle else { return }
        HapticManager.selection()
        let turningOn = !captureSettings.maxQualityCapture
        captureSettings.maxQualityCapture = turningOn
        if turningOn {
            showInlineToast("Max Quality pauses briefly for best photo quality.")
        }
    }

    func startCountdown() {
        guard !isCountingDown else { return }
        guard captureReadiness.isShutterEnabled else { return }
        isCountingDown = true
        countdownValue = timerLength

        Task {
            while countdownValue > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !isCountingDown { return }
                countdownValue -= 1
            }
            if isCountingDown {
                if captureReadiness.isShutterEnabled {
                    executeCapture()
                }
                isCountingDown = false
            }
        }
    }

    func executeCapture() {
        if isCapturing {
            showInlineToast("Capture in progress")
            return
        }
        guard captureReadiness.isShutterEnabled else { return }

        Task {
            await captureCoordinator.executeCapture(
                cameraMode: cameraMode,
                aspectRatio: selectedAspectRatio,
                guidancePhase: guidancePhase,
                analysis: analysis
            )

            HapticManager.capture()
            showShutterFlash = true
            try? await Task.sleep(nanoseconds: 100_000_000)
            showShutterFlash = false
        }
    }
}
