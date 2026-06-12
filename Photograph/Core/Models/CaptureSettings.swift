//
//  CaptureSettings.swift
//  Photograph
//
//  User preferences for Option F capture modes.
//

import Foundation

/// Persisted capture preferences (`UserDefaults`).
@MainActor
final class CaptureSettings {

    static let shared = CaptureSettings()

    private let defaults = UserDefaults.standard
    private let maxQualityKey = "settings.maxQualityCapture"

    private init() {}

    /// User opt-in for Max Quality Mode (AV every rear shutter).
    var maxQualityCapture: Bool {
        get { defaults.bool(forKey: maxQualityKey) }
        set { defaults.set(newValue, forKey: maxQualityKey) }
    }

    /// Effective Max Quality — requires engineering flag and user toggle.
    var maxQualityCaptureActive: Bool {
        CaptureArchitectureFlags.maxQualityCaptureEnabled && maxQualityCapture
    }
}
