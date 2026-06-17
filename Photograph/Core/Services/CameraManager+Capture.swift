//
//  CameraManager+Capture.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import OSLog
import UIKit

// MARK: - Capture & Settings

extension CameraManager {

    private static let captureLog = Logger(subsystem: "com.barenbaruna.Photograph", category: "AVCapture")

    /// Configures fusion-capable photo output — call after `photoOutput` is attached to the session.
    func configurePhotoOutput(for device: AVCaptureDevice) {
        photoOutput.maxPhotoQualityPrioritization = .quality

        let supported = device.activeFormat.supportedMaxPhotoDimensions
        guard let largest = supported.max(by: {
            Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        }) else {
            configuredMaxPhotoDimensions = nil
            return
        }

        photoOutput.maxPhotoDimensions = largest
        configuredMaxPhotoDimensions = largest

        Self.captureLog.info(
            "Photo output configured max=\(largest.width)x\(largest.height) hevc=\(self.photoOutput.availablePhotoCodecTypes.contains(.hevc))"
        )
    }

    /// Configures and starts rear AV session for handoff capture (awaitable).
    func prepareRearCaptureForHandoff(_ snapshot: CaptureHandoffSnapshot) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                let controls = snapshot.cameraControls
                DispatchQueue.main.async { self.flashMode = controls.flashMode }
                self.configureSession(
                    useFront: false,
                    displayMultiplier: controls.displayMultiplier
                )
                if let device = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device {
                    do {
                        try device.lockForConfiguration()
                        let bias = max(
                            device.minExposureTargetBias,
                            min(device.maxExposureTargetBias, controls.exposureBias)
                        )
                        device.setExposureTargetBias(bias)
                        device.unlockForConfiguration()
                    } catch {
                        // Non-fatal — capture with defaults.
                    }
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                    self.exposureBias = controls.exposureBias
                    continuation.resume()
                }
            }
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    /// Captures a photo and waits for delegate completion (call from MainActor).
    @discardableResult
    func capturePhotoAndWait(aspectRatio: AspectRatioMode, timeout: TimeInterval = 15) async -> Bool {
        capturePhoto(aspectRatio: aspectRatio)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isCapturingPhoto, capturedPhotoData != nil { return true }
            if !isCapturingPhoto, captureError != nil { return false }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    /// Builds settings for maximum-quality ISP-processed capture (Deep Fusion when available).
    func makeMaximumQualityPhotoSettings(useFront: Bool) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }

        settings.photoQualityPrioritization = .balanced

        if let dimensions = configuredMaxPhotoDimensions ?? Optional(photoOutput.maxPhotoDimensions),
           dimensions.width > 0, dimensions.height > 0 {
            settings.maxPhotoDimensions = dimensions
        }

        if !useFront {
            settings.flashMode = flashMode
        }

        return settings
    }
    private var activeVideoDevice: AVCaptureDevice? {
        session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first?.device
    }

    // MARK: - Exposure

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeVideoDevice else { return }
            do {
                try device.lockForConfiguration()

                // Clamp to device limits
                let minBias = device.minExposureTargetBias
                let maxBias = device.maxExposureTargetBias
                let clampedBias = max(minBias, min(maxBias, bias))

                device.setExposureTargetBias(clampedBias)
                device.unlockForConfiguration()

                DispatchQueue.main.async { self.exposureBias = clampedBias }
            } catch {
                // Ignore error
            }
        }
    }

    /// Sets display-space zoom multiplier on the virtual rear camera.
    func setZoomFactor(_ displayMultiplier: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeVideoDevice else { return }
            let application = self.zoomMapping.map(
                displayMultiplier: displayMultiplier,
                path: .avLive,
                capabilities: self.zoomCapabilities
            )
            do {
                try device.lockForConfiguration()
                let clamped = min(
                    max(application.deviceVideoZoomFactor, device.minAvailableVideoZoomFactor),
                    device.maxAvailableVideoZoomFactor
                )
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                // Ignore transient configuration failures.
            }
        }
    }

    func focusAndExpose(at devicePoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeVideoDevice else { return }
            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = device.isFocusModeSupported(.continuousAutoFocus) ? .continuousAutoFocus : .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = device.isExposureModeSupported(.continuousAutoExposure) ? .continuousAutoExposure : .autoExpose
                }

                device.unlockForConfiguration()
            } catch {
                // Ignore transient configuration failures.
            }
        }
    }

    // MARK: - Switch Camera

    func switchCamera(completion: (@MainActor () -> Void)? = nil) {
        let newValue = !isUsingFrontCamera
        DispatchQueue.main.async {
            self.isUsingFrontCamera = newValue
            self.selectedLens = .wide
        }
        sessionQueue.async { [weak self] in
            self?.configureSession(useFront: newValue, displayMultiplier: 1.0)
            if let completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    func cycleFlash() {
        guard !isUsingFrontCamera else { return }
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    // MARK: - Capture Photo

    func capturePhoto(aspectRatio: AspectRatioMode = .fourThree) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            DispatchQueue.main.async {
                self.isCapturingPhoto = true
                self.captureError = nil
                self.capturedImage = nil
                self.capturedPhotoData = nil
            }

            self.pendingAspectRatio = aspectRatio

            if self.isUsingFrontCamera {
                DispatchQueue.main.async {
                    UIApplication.shared
                        .connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?
                        .windows
                        .first?
                        .screen
                        .brightness = 1.0
                }
            }

            let settings = self.makeMaximumQualityPhotoSettings(useFront: self.isUsingFrontCamera)
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}
