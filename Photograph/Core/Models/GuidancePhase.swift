//
//  GuidancePhase.swift
//  Soolene
//
//  Explicit state machine for the camera guidance flow.
//  Replaces the implicit ML-driven composition switching with user-driven intent.
//
//  Flow: scanning → subjectLocked → guiding → perfect
//        ↑ double-tap resets to scanning at any point
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import CoreGraphics
import Foundation

/// Represents the current phase of the composition guidance system.
///
/// The phase is driven by **user actions**, not by ML predictions:
/// - `.scanning`: No subject selected. Vision runs at low FPS for visual hints.
/// - `.subjectLocked`: User has long-pressed a subject. ML runs ONCE for suggestion.
/// - `.guiding`: User has chosen a composition. Dual-Anchor guidance is active. ML is OFF.
/// - `.perfect`: Subject is at the ideal position. Ready to capture.
enum GuidancePhase: Equatable {

    /// No subject selected. Vision runs saliency at low FPS for visual hints.
    /// UI: Clean preview; optional scanning coach (viewfinder / saliency hints only).
    case scanning

    /// User has long-pressed a subject. VNTrackObjectRequest is active.
    /// ML runs ONCE to suggest a composition. Composition Picker appears.
    /// UI: Subject bracket materializes, lock icon flashes, picker slides up.
    case subjectLocked(subjectPoint: CGPoint)

    /// User has chosen a composition (or accepted ML suggestion).
    /// Dual-Anchor guidance is active. ML slow tier is OFF.
    /// UI: Full grid overlay, subject bracket, target socket, connector line.
    case guiding(composition: CompositionType)

    /// Subject is at the ideal position for the chosen composition.
    /// UI: Green glow, checkmark merge, shutter button pulses.
    case perfect(composition: CompositionType)

    // MARK: - Convenience

    /// True when the guidance system is actively helping the user compose.
    var isActive: Bool {
        switch self {
        case .guiding, .perfect: return true
        default: return false
        }
    }

    /// True when the subject has been locked (any phase after scanning).
    var isLocked: Bool {
        switch self {
        case .scanning: return false
        default: return true
        }
    }

    /// True when composition is perfectly aligned.
    var isPerfect: Bool {
        if case .perfect = self { return true }
        return false
    }

    /// The active composition type, if any.
    var composition: CompositionType? {
        switch self {
        case .guiding(let comp), .perfect(let comp): return comp
        default: return nil
        }
    }

    /// True when the composition picker should be visible.
    var showPicker: Bool {
        switch self {
        case .scanning: return false
        default: return true
        }
    }

    /// True when the full composition grid overlay should render.
    var showsCompositionGrid: Bool {
        switch self {
        case .guiding, .perfect: return true
        default: return false
        }
    }
}
