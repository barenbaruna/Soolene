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

        worldConfiguration = config
        return config
    }

    func run(resetAnchors: Bool, reattach anchor: ARAnchor?) {
        guard let config = worldConfiguration ?? buildConfiguration() else { return }
        let options: ARSession.RunOptions = resetAnchors
            ? [.resetTracking, .removeExistingAnchors]
            : []
        session.run(config, options: options)
        if let anchor {
            session.add(anchor: anchor)
        }
        configureContinuousAutoFocus()
    }

    func runPreservingConfiguration() {
        guard let config = worldConfiguration else { return }
        session.run(config)
        configureContinuousAutoFocus()
    }

    /// Resumes AR after AV handoff using a **one-shot** world map (never stored on `worldConfiguration`).
    func runWithWorldMap(_ worldMap: ARWorldMap, reattach anchor: ARAnchor?) {
        guard var config = worldConfiguration ?? buildConfiguration() else { return }
        config.initialWorldMap = worldMap
        session.run(config, options: [])
        config.initialWorldMap = nil
        worldConfiguration = config
        if let anchor {
            session.add(anchor: anchor)
        }
        configureContinuousAutoFocus()
    }

    /// Fallback resume when relocalization from world map fails or map unavailable.
    func runAfterHandoffWithoutWorldMap(reattach anchor: ARAnchor?) {
        guard var config = worldConfiguration ?? buildConfiguration() else { return }
        config.initialWorldMap = nil
        worldConfiguration = config
        session.run(config, options: [.resetTracking])
        if let anchor {
            session.add(anchor: anchor)
        }
        configureContinuousAutoFocus()
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
