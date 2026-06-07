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
    // MARK: - Exposure

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else { return }
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

    // MARK: - Switch Camera

    func switchCamera() {
        let newValue = !isUsingFrontCamera
        DispatchQueue.main.async {
            self.isUsingFrontCamera = newValue
            self.selectedLens = .wide
        }
        sessionQueue.async { [weak self] in
            self?.configureSession(useFront: newValue, lens: .wide)
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
