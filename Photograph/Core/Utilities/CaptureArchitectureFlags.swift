//
//  CaptureArchitectureFlags.swift
//  Photograph
//

import Foundation

/// Engineering flags for Option F capture architecture (remote config later).
enum CaptureArchitectureFlags {
    /// Master switch for Max Quality UI and capture path.
    #if DEBUG
    static var maxQualityCaptureEnabled = true
    #else
    static var maxQualityCaptureEnabled = false
    #endif

    /// AV fallback after AR hi-res failure (Default Mode).
    static var avFallbackEnabled = true

    /// OSLog `CaptureTelemetry` events.
    static var telemetryEnabled = true

    /// Continuous zoom ruler (replaces lens chips).
    static var zoomRulerEnabled = true
}
