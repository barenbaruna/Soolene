//
//  CameraManager+Capture.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import UIKit

// MARK: - Capture & Settings

extension CameraManager {
    private var activeVideoDevice: AVCaptureDevice? {
        session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first?.device
    }

    var currentZoomFactor: CGFloat {
        activeVideoDevice?.videoZoomFactor ?? 1
    }

    var maximumZoomFactor: CGFloat {
        guard let device = activeVideoDevice else { return 1 }
        return min(device.maxAvailableVideoZoomFactor, 10)
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

    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeVideoDevice else { return }
            do {
                try device.lockForConfiguration()
                let clampedFactor = min(max(factor, device.minAvailableVideoZoomFactor), min(device.maxAvailableVideoZoomFactor, 10))
                device.videoZoomFactor = clampedFactor
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
            self?.configureSession(useFront: newValue, lens: .wide)
            if let completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    func switchLens(_ lens: LensType) {
        guard !isUsingFrontCamera else { return }
        DispatchQueue.main.async { self.selectedLens = lens }
        sessionQueue.async { [weak self] in
            self?.configureSession(useFront: false, lens: lens)
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

    func capturePhoto(aspectRatio: AspectRatioMode = .free) {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality

        pendingAspectRatio = aspectRatio

        if !isUsingFrontCamera {
            settings.flashMode = flashMode
        } else {
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

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}
