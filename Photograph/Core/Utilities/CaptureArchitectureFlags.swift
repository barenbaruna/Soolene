//
//  CaptureArchitectureFlags.swift
//  Photograph
//

import Foundation

/// Engineering flags for Option B + E-lite capture architecture (remote config later).
enum CaptureArchitectureFlags {
    /// AV handoff when display zoom ≠ 1× (E-lite primary path for zoomed rear capture).
    static var elLiteCaptureEnabled = true

    /// AV fallback after AR hi-res failure at baseline zoom only.
    static var avFallbackEnabled = true

    /// OSLog `CaptureTelemetry` events.
    static var telemetryEnabled = true

    /// Continuous zoom ruler (replaces lens chips).
    static var zoomRulerEnabled = true
}
