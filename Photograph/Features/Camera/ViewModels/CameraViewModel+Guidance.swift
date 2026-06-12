//
//  CameraViewModel+Guidance.swift
//  Photograph
//

import ARKit
import Foundation

extension CameraViewModel {

    var guidanceTip: String {
        if let warning = trackingQualityWarning {
            return warning
        }
        if let label = recommendedCompositionLabel,
           case .guiding = guidancePhase {
            return label
        }

        switch guidancePhase {
        case .scanning:
            if cameraMode == .rearSpatial, spatialEngine.trackingState != .normal {
                return "Move slowly while spatial tracking initializes"
            }
            return "Long-press your subject"
        case .subjectLocked:
            return mlSuggestion.map { "Best fit: \($0.shortLabel) — tap to change" }
                ?? "Analyzing scene for best composition"
        case .guiding(let comp):
            let technique = GuidanceEngine.techniqueForUserSelection(
                composition: comp,
                geometry: analysis.sceneGeometry
            )
            return technique.tip
        case .perfect:
            if isCaptureReady {
                return "Perfect. Capture now."
            }
            return "Hold steady — stabilizing tracking for capture"
        }
    }

    var showsDualAnchorGuidance: Bool {
        guard guidancePhase.isActive else { return false }
        guard userSelectedComposition != nil else { return false }
        return resolvedComposition != .horizontal
    }

    var showsTrackingStabilityMeter: Bool {
        cameraMode == .rearSpatial && isStabilizingForCapture
    }

    var trackingStabilityProgress: Float {
        spatialEngine.trackingStabilityProgress
    }

    func updateTrackingWarning(for state: ARCamera.TrackingState) {
        guard cameraMode == .rearSpatial else { return }
        switch state {
        case .limited(let reason):
            trackingQualityWarning = limitedTrackingMessage(reason)
        case .notAvailable:
            trackingQualityWarning = "Move the device slowly to restore tracking."
        case .normal:
            if trackingQualityWarning?.contains("approximate") != true
                && trackingQualityWarning?.contains("world lock") != true {
                trackingQualityWarning = nil
            }
        }
    }

    private func limitedTrackingMessage(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .excessiveMotion:
            return "Move the device more slowly."
        case .insufficientFeatures:
            return "Point at a textured surface for better tracking."
        case .initializing:
            return "Initializing spatial tracking…"
        case .relocalizing:
            return "Relocalizing — hold steady."
        @unknown default:
            return "Tracking is limited — hold steady."
        }
    }
}
