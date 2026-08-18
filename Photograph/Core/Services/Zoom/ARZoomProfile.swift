//
//  ARZoomProfile.swift
//  Soolene
//
//  Maps display-space zoom to AR primary camera `videoZoomFactor`.
//  On Pro/Max, ARKit often uses the ultra-wide as the primary feed — display 1×
//  corresponds to ~2× device zoom, not 1×.
//

import ARKit
import AVFoundation
import CoreGraphics

struct ARZoomProfile: Equatable, Sendable {
    var primaryIsUltraWide: Bool
    var wideSwitchFactor: CGFloat

    static let widePrimary = ARZoomProfile(primaryIsUltraWide: false, wideSwitchFactor: 2.0)

    /// Detects the active AR primary camera after the session is running.
    static func detect(capabilities: ZoomDeviceCapabilities) -> ARZoomProfile {
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else {
            return .widePrimary
        }

        let isUltraWide = device.deviceType == .builtInUltraWideCamera
        let wideFactor = capabilities.switchOverFactors
            .first(where: { $0 >= 1.5 && $0 < 10 }) ?? 2.0

        return ARZoomProfile(
            primaryIsUltraWide: isUltraWide,
            wideSwitchFactor: wideFactor
        )
    }

    func deviceVideoZoomFactor(for displayMultiplier: CGFloat) -> CGFloat {
        if primaryIsUltraWide {
            if displayMultiplier < 1.0 {
                return 1.0
            }
            return displayMultiplier * wideSwitchFactor
        }
        if displayMultiplier < 1.0 {
            return 1.0
        }
        return displayMultiplier
    }
}
