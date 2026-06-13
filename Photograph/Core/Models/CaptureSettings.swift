//
//  CaptureSettings.swift
//  Photograph
//
//  User preferences for capture modes.
//

import Foundation

/// Persisted capture preferences (`UserDefaults`).
@MainActor
final class CaptureSettings {

    static let shared = CaptureSettings()

    private init() {}
}
