//
//  ZoomMappingEngine.swift
//  Photograph
//
//  Maps user-facing display multiplier ↔ device videoZoomFactor per capture path.
//
//  Architecture:
//  - `.arGuidance`: Single AR primary lens (`configurableCaptureDeviceForPrimaryCamera`).
//    Digital zoom only on that physical lens — no virtual multi-camera switching.
//    Display ↔ device mapping uses `ARZoomProfile` (ultra-wide primary maps 1× ≈ 2× device).
//  - `.avLive` / `.avHandoff`: Rear virtual device (triple/dual wide). iOS switches
//    physical lenses at `virtualDeviceSwitchOverVideoZoomFactors`; display ≈ device zoom.
//

import CoreGraphics
import Foundation

/// Capture pipeline that receives zoom commands from `ZoomMappingEngine`.
enum CaptureZoomPath: Equatable, Sendable {
    /// Live AR guidance preview (visual zoom on `ARSCNView`; hardware zoom best-effort).
    case arGuidance
    /// Front camera or AV-only live session.
    case avLive
    /// Rear AV handoff / Max Quality capture (virtual triple camera).
    case avHandoff
}

/// Origin of a zoom change — used for haptics and telemetry.
enum ZoomInputSource: Equatable, Sendable {
    case ruler
    case pinch
    case handoffRestore
    case lensMigration
}

/// Result of mapping display-space zoom to a device command for one path.
struct ZoomApplication: Equatable, Sendable {
    var displayMultiplier: CGFloat
    var deviceVideoZoomFactor: CGFloat
    var isPreviewApproximate: Bool
    var activePhysicalLens: PhysicalLens?
}

/// Converts display-space zoom to device commands for each capture path.
struct ZoomMappingEngine: Sendable {

    func map(
        displayMultiplier: CGFloat,
        path: CaptureZoomPath,
        capabilities: ZoomDeviceCapabilities,
        arProfile: ARZoomProfile = .widePrimary
    ) -> ZoomApplication {
        let maxDisplay: CGFloat
        switch path {
        case .arGuidance:
            maxDisplay = capabilities.arMaxDisplayZoom
        case .avLive, .avHandoff:
            maxDisplay = capabilities.maxDisplayZoom
        }

        let display = clamp(
            displayMultiplier,
            capabilities.minDisplayZoom,
            maxDisplay
        )

        switch path {
        case .arGuidance:
            return mapARGuidance(display: display, capabilities: capabilities, arProfile: arProfile)
        case .avLive, .avHandoff:
            return mapAV(display: display, capabilities: capabilities)
        }
    }

    func displayMultiplier(fromDeviceZoom deviceZoom: CGFloat, capabilities: ZoomDeviceCapabilities) -> CGFloat {
        clamp(deviceZoom, capabilities.minDisplayZoom, capabilities.maxDisplayZoom)
    }

    func softSnapTarget(
        for display: CGFloat,
        boundaries: [CGFloat],
        threshold: CGFloat = 0.05
    ) -> CGFloat? {
        for boundary in boundaries where abs(display - boundary) <= threshold {
            return boundary
        }
        return nil
    }

    // MARK: - Private

    private func mapARGuidance(
        display: CGFloat,
        capabilities: ZoomDeviceCapabilities,
        arProfile: ARZoomProfile
    ) -> ZoomApplication {
        var approximate = false
        let deviceZoom = arProfile.deviceVideoZoomFactor(for: display)

        if display < 1.0, capabilities.hasUltraWide {
            approximate = true
        } else if display >= (capabilities.teleDisplayMultiplier ?? capabilities.arMaxDisplayZoom) - 0.1 {
            approximate = true
        }

        return ZoomApplication(
            displayMultiplier: display,
            deviceVideoZoomFactor: deviceZoom,
            isPreviewApproximate: approximate,
            activePhysicalLens: physicalLens(for: display, capabilities: capabilities)
        )
    }

    private func mapAV(
        display: CGFloat,
        capabilities: ZoomDeviceCapabilities
    ) -> ZoomApplication {
        ZoomApplication(
            displayMultiplier: display,
            deviceVideoZoomFactor: display,
            isPreviewApproximate: false,
            activePhysicalLens: physicalLens(for: display, capabilities: capabilities)
        )
    }

    private func physicalLens(
        for display: CGFloat,
        capabilities: ZoomDeviceCapabilities
    ) -> PhysicalLens? {
        if display < 0.75, capabilities.hasUltraWide { return .ultraWide }
        if let tele = capabilities.teleDisplayMultiplier, display >= tele - 0.15 {
            return tele >= 4.5 ? .tele5x : .tele3x
        }
        if display >= 1.75 { return .wide }
        return .wide
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
