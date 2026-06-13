//
//  CaptureArchitectureFlags.swift
//  Photograph
//

import Foundation

/// Engineering flags for Option F capture architecture (remote config later).
enum CaptureArchitectureFlags {
    /// AV fallback after AR hi-res failure (Default Mode).
    static var avFallbackEnabled = true

    /// OSLog `CaptureTelemetry` events.
    static var telemetryEnabled = true

    /// Continuous zoom ruler (replaces lens chips).
    static var zoomRulerEnabled = true
}
