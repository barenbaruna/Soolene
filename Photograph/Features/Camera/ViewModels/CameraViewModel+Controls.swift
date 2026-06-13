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

    // MARK: - Zoom (continuous ruler)

    var showsZoomRuler: Bool {
        CaptureArchitectureFlags.zoomRulerEnabled
            && cameraMode == .rearSpatial
            && !isCountingDown
    }

    func setZoomMultiplier(_ multiplier: CGFloat, isFinal: Bool) {
        guard !isSwitchingCamera else { return }
        let application = zoomController.setDisplayMultiplier(
            multiplier,
            source: .ruler,
            path: currentZoomPath,
            emitHaptics: !isFinal
        )
        applyZoomApplication(application)
        if isFinal, let snap = zoomController.onRulerDragEnded() {
            let snapped = zoomController.setDisplayMultiplier(
                snap,
                source: .ruler,
                path: currentZoomPath,
                emitHaptics: false
            )
            applyZoomApplication(snapped)
        }
    }

    func onZoomRulerDragBegan() {
        zoomController.onRulerDragBegan()
    }

    func updateZoom(magnification: CGFloat, isFinal: Bool) {
        guard !isSwitchingCamera else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if !isFinal, now - lastZoomApplyTime < 1.0 / 30.0 { return }
        lastZoomApplyTime = now

        if isFinal {
            defer { pinchStartMultiplier = nil }
            guard let start = pinchStartMultiplier else { return }
            let application = zoomController.setDisplayMultiplier(
                start * magnification,
                source: .pinch,
                path: currentZoomPath,
                emitHaptics: false
            )
            applyZoomApplication(application)
            return
        }

        if pinchStartMultiplier == nil {
            pinchStartMultiplier = zoomController.displayMultiplier
        }
        guard let start = pinchStartMultiplier else { return }

        let application = zoomController.setDisplayMultiplier(
            start * magnification,
            source: .pinch,
            path: currentZoomPath,
            emitHaptics: false
        )
        applyZoomApplication(application)
    }

    func refreshARZoomAfterSessionStart() {
        guard cameraMode == .rearSpatial else { return }
        zoomController.refreshARZoomProfile()
        applyZoomApplication(zoomController.mapForPath(.arGuidance))
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
        case 3: timerLength = 5
        case 5: timerLength = 0
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

    // MARK: - Private

    private var currentZoomPath: CaptureZoomPath {
        switch cameraMode {
        case .rearSpatial: .arGuidance
        case .frontClassic: .avLive
        }
    }

    private func applyZoomApplication(_ application: ZoomApplication) {
        spatialEngine.displayMultiplier = application.displayMultiplier
        spatialEngine.isZoomPreviewApproximate = application.isPreviewApproximate
        let lens = LensType.preset(
            containing: application.displayMultiplier,
            in: LensType.availableOnDevice
        )
        spatialEngine.selectedLens = lens
        cameraManager.selectedLens = lens

        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setZoomFactor(application.deviceVideoZoomFactor)
        case .frontClassic:
            cameraManager.setZoomFactor(application.displayMultiplier)
        }

        CaptureTelemetry.recordZoomSet(
            displayMultiplier: application.displayMultiplier,
            path: currentZoomPath,
            deviceZoom: application.deviceVideoZoomFactor,
            physicalLens: application.activePhysicalLens?.rawValue
        )
    }
}
