//
//  CaptureTelemetry.swift
//  Photograph
//
//  OSLog metrics for Option F capture architecture (§15 spec).
//

import Foundation
import OSLog

/// Structured capture metrics — filter Console with subsystem `com.barenbaruna.Photograph` category `CaptureTelemetry`.
enum CaptureTelemetry {

    enum CaptureMode: String {
        case `default`
        case maxQuality
        case frontClassic
    }

    enum CapturePath: String {
        case ar
        case av
        case avFallback
        case maxQuality
    }

    private static let log = Logger(
        subsystem: "com.barenbaruna.Photograph",
        category: "CaptureTelemetry"
    )

    private static var shutterAttempts = 0
    private static var captureSuccesses = 0
    private static var fallbackAttempts = 0
    private static var handoffCount = 0
    private static var handoffTrackingRecovered = 0

    // MARK: - Events

    static func recordShutterAttempt(mode: CaptureMode) {
        guard CaptureArchitectureFlags.telemetryEnabled else { return }
        shutterAttempts += 1
        log.info("shutter_attempt mode=\(mode.rawValue) total=\(shutterAttempts)")
    }

    static func recordCaptureComplete(
        mode: CaptureMode,
        path: CapturePath,
        success: Bool,
        latencyMs: Int,
        bytes: Int? = nil,
        dimensions: String? = nil,
        arErrorCode: Int? = nil,
        thermal: Int? = nil
    ) {
        guard CaptureArchitectureFlags.telemetryEnabled else { return }
        if success { captureSuccesses += 1 }

        var parts = [
            "capture_result mode=\(mode.rawValue)",
            "path=\(path.rawValue)",
            "success=\(success)",
            "latencyMs=\(latencyMs)",
            "successRate=\(successRatePercent)%"
        ]
        if let bytes { parts.append("bytes=\(bytes)") }
        if let dimensions { parts.append("dimensions=\(dimensions)") }
        if let arErrorCode { parts.append("arErrorCode=\(arErrorCode)") }
        if let thermal { parts.append("thermal=\(thermal)") }
        log.info("\(parts.joined(separator: " "))")
    }

    static func recordHandoffComplete(
        path: CapturePath,
        success: Bool,
        usedWorldMap: Bool,
        trackingRecovered: Bool,
        elapsedMs: Int,
        frozenPreviewMs: Int? = nil
    ) {
        guard CaptureArchitectureFlags.telemetryEnabled else { return }
        handoffCount += 1
        if trackingRecovered { handoffTrackingRecovered += 1 }
        if path == .avFallback { fallbackAttempts += 1 }

        var parts = [
            "handoff_result path=\(path.rawValue)",
            "success=\(success)",
            "usedWorldMap=\(usedWorldMap)",
            "trackingRecovered=\(trackingRecovered)",
            "elapsedMs=\(elapsedMs)",
            "relocalizationRate=\(relocalizationSuccessPercent)%"
        ]
        if let frozenPreviewMs { parts.append("frozenPreviewMs=\(frozenPreviewMs)") }
        if path == .avFallback {
            parts.append("fallbackRate=\(fallbackRatePercent)%")
        }
        log.info("\(parts.joined(separator: " "))")
    }

    static func recordZoomSet(
        displayMultiplier: CGFloat,
        path: CaptureZoomPath,
        deviceZoom: CGFloat,
        physicalLens: String?
    ) {
        guard CaptureArchitectureFlags.telemetryEnabled else { return }
        var parts = [
            "zoom_set display=\(String(format: "%.2f", displayMultiplier))",
            "path=\(pathTelemetryKey(path))",
            "deviceZoom=\(String(format: "%.2f", deviceZoom))"
        ]
        if let physicalLens { parts.append("lens=\(physicalLens)") }
        log.info("\(parts.joined(separator: " "))")
    }

    private static func pathTelemetryKey(_ path: CaptureZoomPath) -> String {
        switch path {
        case .arGuidance: return "arGuidance"
        case .avLive: return "avLive"
        case .avHandoff: return "avHandoff"
        }
    }

    // MARK: - Aggregates (in-process)

    private static var successRatePercent: Int {
        guard shutterAttempts > 0 else { return 0 }
        return (captureSuccesses * 100) / shutterAttempts
    }

    private static var fallbackRatePercent: Int {
        guard shutterAttempts > 0 else { return 0 }
        return (fallbackAttempts * 100) / shutterAttempts
    }

    private static var relocalizationSuccessPercent: Int {
        guard handoffCount > 0 else { return 0 }
        return (handoffTrackingRecovered * 100) / handoffCount
    }
}
