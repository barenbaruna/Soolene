//
//  HapticManager.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import UIKit

/// Manages all haptic feedback in the app to conform to Apple HIG.
enum HapticManager {
    /// Used for capturing a photo. Provides a satisfying "clunk".
    static func capture() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Used when the user perfectly aligns the composition.
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Used when tracking stabilizes and capture becomes available.
    static func captureReady() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Used when the user locks a subject with a long-press.
    static func lock() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.85)
    }

    /// Used for small UI interactions like switching settings or camera lenses.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// General-purpose notification feedback (success, warning, error).
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
