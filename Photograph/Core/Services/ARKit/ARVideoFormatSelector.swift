//
//  ARVideoFormatSelector.swift
//  Soolene
//
//  Option B: prefer main/wide camera as AR primary at session start.
//

import ARKit
import AVFoundation

/// Selects an AR world-tracking video format with wide-angle primary when available.
enum ARVideoFormatSelector {

    enum SelectionSource: String, Sendable {
        case widePrimaryHiRes
        case widePrimaryBest
        case hiResRecommendedFallback
    }

    struct Selection: Sendable {
        var format: ARConfiguration.VideoFormat
        var source: SelectionSource
    }

    /// Priority: wide + hi-res recommended → best wide → hi-res recommended (may be UW).
    static func selectPreferredFormat(
        from formats: [ARConfiguration.VideoFormat]
    ) -> Selection? {
        if let format = formats.first(where: {
            $0.captureDeviceType == .builtInWideAngleCamera
                && $0.isRecommendedForHighResolutionFrameCapturing
        }) {
            return Selection(format: format, source: .widePrimaryHiRes)
        }

        if let format = formats.first(where: {
            $0.captureDeviceType == .builtInWideAngleCamera
        }) {
            return Selection(format: format, source: .widePrimaryBest)
        }

        if let format = fallbackFormat(from: formats) {
            return Selection(format: format, source: .hiResRecommendedFallback)
        }

        return nil
    }

    static func fallbackFormat(
        from formats: [ARConfiguration.VideoFormat]
    ) -> ARConfiguration.VideoFormat? {
        if let recommended = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
            return recommended
        }
        return formats.first(where: { $0.isRecommendedForHighResolutionFrameCapturing })
    }

    static func formatDescription(_ format: ARConfiguration.VideoFormat) -> String {
        let device = format.captureDeviceType.rawValue
        let res = format.imageResolution
        let hiRes = format.isRecommendedForHighResolutionFrameCapturing
        return "\(device) \(Int(res.width))x\(Int(res.height))@\(format.framesPerSecond)fps hiRes=\(hiRes)"
    }
}
