//
//  Spacing.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import CoreGraphics
import Foundation

/// Standardized spacing and corner radius tokens matching the Design System spec.
enum Spacing {

    // MARK: - Spacing

    static let tiny: CGFloat       = 4
    static let small: CGFloat      = 8
    static let standard: CGFloat   = 16
    static let medium: CGFloat     = 24
    static let large: CGFloat      = 32
    static let extraLarge: CGFloat = 48
    static let massive: CGFloat    = 64

    // MARK: - Corner Radius

    /// 8pt — small cards, chips
    static let cornerRadiusSmall: CGFloat     = 8
    /// 12pt — medium cards
    static let cornerRadiusMedium: CGFloat    = 12
    /// 16pt — standard cards and sheets
    static let cornerRadiusLarge: CGFloat     = 16
    /// 62pt — very-very large (circular buttons, pill-shaped frames)
    static let cornerRadiusXXLarge: CGFloat   = 62
    /// 20pt — capsule/pill shape
    static let cornerRadiusCapsule: CGFloat   = 20
}

enum ControlMetrics {
    static let iconButton: CGFloat = 56
    static let compactIconButton: CGFloat = 44
    static let settingsButton: CGFloat = 40
    static let shutterOuter: CGFloat = 80
    static let shutterInner: CGFloat = 64
    static let galleryThumbnail: CGFloat = 56
    static let cameraBottomBandHeight: CGFloat = 112
    static let settingsSheetHeight: CGFloat = 240
    static let settingsSheetIcon: CGFloat = 52
    static let focusIndicator: CGFloat = 64
    static let focusBox: CGFloat = 116
    static let exposureRailWidth: CGFloat = 44
    static let exposureRailHeight: CGFloat = 228
    static let exposureControlWidth: CGFloat = 328

    /// Interior tick track height (shared with `LiquidGlassRuler`).
    static let rulerTrackHeight: CGFloat = 44
    static let topScrimHeight: CGFloat = 128

    // MARK: - Composition Picker

    static let compositionPillWidth: CGFloat = 72
    static let compositionPillHeight: CGFloat = 80
    static let compositionPickerHeight: CGFloat = 96

    // MARK: - Dual-Anchor Overlay

    static let dualAnchorBracketSize: CGFloat = 48
    static let dualAnchorSocketFar: CGFloat = 60
    static let dualAnchorSocketClose: CGFloat = 72
}
