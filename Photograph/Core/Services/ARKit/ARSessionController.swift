//
//  ARSessionController.swift
//  Photograph
//

import ARKit
import AVFoundation

/// ARKit session configuration and run/pause lifecycle.
final class ARSessionController {

    let session: ARSession
    private(set) var worldConfiguration: ARWorldTrackingConfiguration?

    init(session: ARSession) {
        self.session = session
    }

    func buildConfiguration() -> ARWorldTrackingConfiguration? {
        guard ARWorldTrackingConfiguration.isSupported else { return nil }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.isAutoFocusEnabled = true
        config.worldAlignment = .gravity

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        if let recommended = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
            config.videoFormat = recommended
        } else if let hiResFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: {
            $0.isRecommendedForHighResolutionFrameCapturing
        }) {
            config.videoFormat = hiResFormat
        }

        configureContinuousAutoFocus()
        worldConfiguration = config
        return config
    }

    func run(resetAnchors: Bool, reattach anchor: ARAnchor?) {
        guard let config = worldConfiguration ?? buildConfiguration() else { return }
        let options: ARSession.RunOptions = resetAnchors ? [.resetTracking, .removeExistingAnchors] : [.resetTracking]
        session.run(config, options: options)
        if let anchor {
            session.add(anchor: anchor)
        }
    }

    func runPreservingConfiguration() {
        guard let config = worldConfiguration else { return }
        session.run(config)
    }

    func pause() {
        session.pause()
    }

    private func configureContinuousAutoFocus() {
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // Non-fatal — ARKit still runs with default focus.
        }
    }
}
