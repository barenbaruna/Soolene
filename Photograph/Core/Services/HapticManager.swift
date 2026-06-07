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

    /// Used for small UI interactions like switching settings or camera lenses.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
