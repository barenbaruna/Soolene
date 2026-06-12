//
//  CaptureReadiness.swift
//  Photograph
//
//  Single source of truth for guidance UI, shutter, and capture gates.
//

import Foundation

/// Unified capture readiness — drives label, grid, dual-anchor, shutter, and haptics.
enum CaptureReadiness: Equatable {
    case scanning
    case subjectLocked
    case aligning(composition: CompositionType, progress: Float)
    case compositionReady(composition: CompositionType)
    case captureReady(composition: CompositionType)
    case capturing
    case handoffRecovering

    // MARK: - UI mapping

    /// Green shutter ring — capture enabled.
    var isShutterEnabled: Bool {
        if case .captureReady = self { return true }
        return false
    }

    /// Drives `CaptureButton` olive / gold / green styling.
    var shutterVisual: ShutterReadiness {
        switch self {
        case .captureReady:
            return .ready
        case .compositionReady, .handoffRecovering, .capturing:
            return .stabilizing
        case .aligning(_, let progress) where progress >= 0.85:
            return .stabilizing
        default:
            return .idle
        }
    }

    /// Full green celebration (grid, dual-anchor merge, tip checkmark).
    var showsGreenCelebration: Bool {
        if case .captureReady = self { return true }
        return false
    }

    /// Gold stabilizing state (composition aligned, hardware pending).
    var showsStabilizingUI: Bool {
        switch self {
        case .compositionReady, .handoffRecovering, .capturing:
            return true
        case .aligning(_, let progress) where progress >= 0.85:
            return true
        default:
            return false
        }
    }

    var activeComposition: CompositionType? {
        switch self {
        case .aligning(let composition, _),
             .compositionReady(let composition),
             .captureReady(let composition):
            return composition
        default:
            return nil
        }
    }
}
