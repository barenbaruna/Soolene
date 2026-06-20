//
//  ZoomController.swift
//  Soolene
//
//  Single source of truth for display-space zoom multiplier and boundary haptics.
//

import AVFoundation
import CoreGraphics
import Foundation

@MainActor
@Observable
final class ZoomController {
    private(set) var displayMultiplier: CGFloat = 1.0
    private(set) var isPreviewApproximate = false

    let capabilities: ZoomDeviceCapabilities
    private(set) var arZoomProfile: ARZoomProfile = .widePrimary
    private(set) var tickLayout: ZoomRulerTickLayout
    private let mapping = ZoomMappingEngine()
    private let haptics = RulerHapticEngine()

    var displayRange: ClosedRange<CGFloat> { capabilities.displayRange }
    var tickBoundaries: [CGFloat] { tickLayout.majorBoundaries }
    var arMaxDisplayZoom: CGFloat { capabilities.arMaxDisplayZoom }

    init(capabilities: ZoomDeviceCapabilities = ZoomDeviceCapabilities.discover()) {
        self.capabilities = capabilities
        self.tickLayout = ZoomRulerTickLayout.make(from: capabilities)
    }

    /// Re-detect AR primary camera after session start (must run while AR session is active).
    func refreshARZoomProfile() {
        arZoomProfile = ARZoomProfile.detect(capabilities: capabilities)
    }

    // MARK: - Input

    @discardableResult
    func setDisplayMultiplier(
        _ value: CGFloat,
        source: ZoomInputSource,
        path: CaptureZoomPath,
        emitHaptics: Bool
    ) -> ZoomApplication {
        let previous = displayMultiplier
        let application = mapping.map(
            displayMultiplier: value,
            path: path,
            capabilities: capabilities,
            arProfile: path == .arGuidance ? arZoomProfile : .widePrimary
        )
        displayMultiplier = application.displayMultiplier
        isPreviewApproximate = application.isPreviewApproximate

        if emitHaptics, source == .ruler {
            haptics.handleValueChange(
                from: previous,
                to: application.displayMultiplier,
                majorBoundaries: tickLayout.majorBoundaries,
                minorStep: tickLayout.minorStep
            )
        }

        return application
    }

    func restore(displayMultiplier: CGFloat, path: CaptureZoomPath) -> ZoomApplication {
        setDisplayMultiplier(displayMultiplier, source: .handoffRestore, path: path, emitHaptics: false)
    }

    func mapForPath(_ path: CaptureZoomPath) -> ZoomApplication {
        mapping.map(
            displayMultiplier: displayMultiplier,
            path: path,
            capabilities: capabilities,
            arProfile: path == .arGuidance ? arZoomProfile : .widePrimary
        )
    }

    func onRulerDragBegan() {
        haptics.prepareForDrag()
        haptics.resetDragState()
    }

    /// Soft snap to nearest major boundary within threshold; returns snapped value if changed.
    func onRulerDragEnded() -> CGFloat? {
        haptics.resetDragState()
        return mapping.softSnapTarget(
            for: displayMultiplier,
            boundaries: tickLayout.majorBoundaries
        )
    }

    func makeControlSnapshot(
        flashMode: AVCaptureDevice.FlashMode,
        exposureBias: Float,
        focusPointNormalized: CGPoint?
    ) -> CameraControlSnapshot {
        CameraControlSnapshot(
            displayMultiplier: displayMultiplier,
            lens: LensType.preset(containing: displayMultiplier, in: LensType.availableOnDevice),
            flashMode: flashMode,
            exposureBias: exposureBias,
            focusPointNormalized: focusPointNormalized
        )
    }
}
