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

        switch captureReadiness {
        case .capturing:
            return "Capturing…"
        case .handoffRecovering:
            return "Realigning guidance…"
        case .compositionReady:
            return "Hold steady — stabilizing tracking for capture"
        case .captureReady:
            return "Perfect. Capture now."
        default:
            break
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
            if cameraMode == .rearSpatial,
               spatialEngine.lastLockQuality == .estimatedFallback {
                return "Subject lock is approximate — point at a textured surface."
            }
            if analysis.sceneGeometry.trackedSubjectPoint == nil {
                return "Locking subject…"
            }
            return mlSuggestion.map { "Suggested: \($0.shortLabel) — tap to change" }
                ?? "Selecting best composition…"
        case .guiding(let comp):
            let technique = GuidanceEngine.techniqueForUserSelection(
                composition: comp,
                geometry: analysis.sceneGeometry
            )
            return technique.tip
        case .perfect:
            return "Hold steady — stabilizing tracking for capture"
        }
    }

    var showsDualAnchorGuidance: Bool {
        guard guidancePhase.isActive else { return false }
        guard userSelectedComposition != nil else { return false }
        return resolvedComposition != .horizontal
    }

    var showsTrackingStabilityMeter: Bool {
        guard cameraMode == .rearSpatial else { return false }
        switch captureReadiness {
        case .compositionReady, .handoffRecovering:
            return true
        default:
            return false
        }
    }

    var trackingStabilityProgress: Float {
        spatialEngine.trackingStabilityProgress
    }

    func syncHandoffRecovery() {
        captureCoordinator.clearHandoffRecoveryIfTrackingStable(
            trackingState: spatialEngine.trackingState,
            stabilityProgress: spatialEngine.trackingStabilityProgress
        )
    }

    func updateTrackingWarning(for state: ARCamera.TrackingState) {
        syncHandoffRecovery()
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
