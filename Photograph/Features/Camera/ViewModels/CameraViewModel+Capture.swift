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

    var isCaptureReady: Bool {
        captureCoordinator.isCaptureReady(
            cameraMode: cameraMode,
            guidancePhase: guidancePhase
        )
    }

    var shutterIsPerfect: Bool {
        shutterReadiness == .ready
    }

    var isCompositionAligned: Bool {
        guidancePhase.isPerfect || analysis.isCompositionPerfect
    }

    var isStabilizingForCapture: Bool {
        shutterReadiness == .stabilizing
    }

    var shutterReadiness: ShutterReadiness {
        captureCoordinator.shutterReadiness(
            cameraMode: cameraMode,
            guidancePhase: guidancePhase,
            isCompositionPerfect: analysis.isCompositionPerfect
        )
    }

    var activeCapturedPhotoData: Data? {
        captureCoordinator.activeCapturedPhotoData
    }

    var captureError: String? {
        captureCoordinator.activeCaptureError
    }

    var isCapturing: Bool {
        captureCoordinator.isCapturing(cameraMode: cameraMode)
    }

    func startCountdown() {
        guard !isCountingDown else { return }
        guard isCaptureReady else { return }
        isCountingDown = true
        countdownValue = timerLength

        Task {
            while countdownValue > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !isCountingDown { return }
                countdownValue -= 1
            }
            if isCountingDown {
                if isCaptureReady {
                    executeCapture()
                }
                isCountingDown = false
            }
        }
    }

    func executeCapture() {
        guard isCaptureReady, !isCapturing else { return }

        Task {
            await captureCoordinator.executeCapture(
                cameraMode: cameraMode,
                aspectRatio: selectedAspectRatio,
                isCaptureReady: isCaptureReady
            )

            HapticManager.capture()
            showShutterFlash = true
            try? await Task.sleep(nanoseconds: 100_000_000)
            showShutterFlash = false
            await savePhoto()
        }
    }
}
