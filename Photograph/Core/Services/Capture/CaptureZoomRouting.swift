//
//  CaptureZoomRouting.swift
//  Soolene
//
//  E-lite capture routing: AR hi-res at baseline zoom, AV handoff when zoomed.
//

import CoreGraphics
import Foundation

enum CaptureZoomRouting {

    /// Matches ruler soft-snap tolerance in `ZoomMappingEngine`.
    static let baselineTolerance: CGFloat = 0.05

    static func isBaselineZoom(_ displayMultiplier: CGFloat) -> Bool {
        abs(displayMultiplier - 1.0) <= baselineTolerance
    }

    /// When E-lite is enabled, non-baseline zoom uses AV virtual-device capture.
    static func shouldUseZoomedAVHandoff(
        displayMultiplier: CGFloat,
        elLiteEnabled: Bool
    ) -> Bool {
        elLiteEnabled && !isBaselineZoom(displayMultiplier)
    }

    /// Effective AR preview scale for FOV crop (sub-1× does not scale the AR feed).
    static func effectivePreviewScale(for displayMultiplier: CGFloat) -> CGFloat {
        displayMultiplier < 1.0 ? 1.0 : displayMultiplier
    }
}
