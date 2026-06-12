//
//  CameraViewModel+Controls.swift
//  Photograph
//

import AVFoundation
import SwiftUI

extension CameraViewModel {

    func switchCamera() {
        guard !isSwitchingCamera else { return }
        HapticManager.selection()
        isSwitchingCamera = true

        Task {
            if cameraMode == .rearSpatial {
                await sessionCoordinator.switchToFrontClassic(
                    hasCameraPermission: hasCameraPermission,
                    checkPermissions: { await self.checkPermissions() }
                )
                cameraMode = .frontClassic
                trackingQualityWarning = "Front camera uses 2D tracking — world lock unavailable."
            } else {
                await sessionCoordinator.switchToRearSpatial()
                cameraMode = .rearSpatial
                trackingQualityWarning = nil
            }
            isSwitchingCamera = false
        }
    }

    func switchLens(_ lens: LensType) {
        guard !isSwitchingCamera else { return }
        HapticManager.selection()
        zoomFactor = lens.zoomFactor
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setZoomFactor(lens.zoomFactor)
        case .frontClassic:
            guard cameraManager.isUsingFrontCamera else { return }
            cameraManager.setZoomFactor(lens.zoomFactor)
        }
    }

    func switchLens(_ rawValue: String) {
        guard let lens = LensType(rawValue: rawValue) else { return }
        switchLens(lens)
    }

    func focusAndExpose(at normalizedPoint: CGPoint) {
        guard !isSwitchingCamera else { return }
        HapticManager.selection()
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.focusAndExpose(at: normalizedPoint)
        case .frontClassic:
            cameraManager.focusAndExpose(at: normalizedPoint)
        }
    }

    func updateZoom(magnification: CGFloat, isFinal: Bool) {
        guard !isSwitchingCamera else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if !isFinal, now - lastZoomApplyTime < 1.0 / 30.0 { return }
        lastZoomApplyTime = now

        let baseZoom = max(zoomFactor, 1)
        let nextZoom = baseZoom * magnification
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setZoomFactor(nextZoom)
            if isFinal {
                zoomFactor = min(max(nextZoom, 1), spatialEngine.maximumZoomFactor)
            }
        case .frontClassic:
            cameraManager.setZoomFactor(nextZoom)
            if isFinal {
                zoomFactor = min(max(nextZoom, 1), cameraManager.maximumZoomFactor)
            }
        }
    }

    func cycleFlash() {
        HapticManager.selection()
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.cycleFlash()
        case .frontClassic:
            break
        }
    }

    func cycleTimer() {
        HapticManager.selection()
        switch timerLength {
        case 0: timerLength = 3
        case 3: timerLength = 10
        case 10: timerLength = 0
        default: timerLength = 0
        }
    }

    func setExposure(_ bias: Float) {
        guard !isSwitchingCamera else { return }
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setExposureBias(bias)
        case .frontClassic:
            cameraManager.setExposureBias(bias)
        }
    }

    func resetExposure() {
        HapticManager.selection()
        setExposure(0)
    }

    func cycleExposure() {
        let current = exposureBias
        let next: Float
        if current == 0 { next = 1.0 }
        else if current == 1.0 { next = 2.0 }
        else if current == 2.0 { next = -2.0 }
        else if current == -2.0 { next = -1.0 }
        else { next = 0.0 }
        HapticManager.selection()
        setExposure(next)
    }

    var flashSymbolName: String {
        switch activeFlashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    var isFrontCamera: Bool { cameraMode == .frontClassic }

    var activeFlashMode: AVCaptureDevice.FlashMode {
        switch cameraMode {
        case .rearSpatial: spatialEngine.flashMode
        case .frontClassic: cameraManager.flashMode
        }
    }

    var flashMode: AVCaptureDevice.FlashMode { activeFlashMode }

    var isFlashActive: Bool {
        activeFlashMode == .on || activeFlashMode == .auto
    }

    var exposureBias: Float {
        switch cameraMode {
        case .rearSpatial: spatialEngine.exposureBias
        case .frontClassic: cameraManager.exposureBias
        }
    }

    var selectedLens: String {
        LensType.closest(toZoom: zoomFactor).rawValue
    }

    var availableLenses: [LensType] {
        cameraMode == .frontClassic ? [.wide] : LensType.availableOnDevice
    }
}
