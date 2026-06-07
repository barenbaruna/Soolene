//
//  AppColors.swift
//  Photograph
//
//  Centralised color tokens matching the Design System spec.
//  Every color used in the app must be referenced from here.
//
//  Color Palette:
//    Primary   #EFC44F  — Primary action, active states (golden yellow)
//    Accent    #12A0FF  — Accent / interactive highlights
//    Text      #FFFFFF  — On-camera text
//    Secondary #000000  — Background surfaces
//    Gridline Red   #D94A3D  — Guide overlay (not yet aligned)
//    Gridline Green #35C75A  — Guide overlay (scene is aligned)
//

import SwiftUI

enum AppColors {
    // MARK: - Brand

    /// #EFC44F — Primary action color (golden yellow).
    /// Used for active states, selected lenses, active flash, and CTA elements.
    static let primary = Color(hex: 0xEFC44F)

    /// #12A0FF — Accent / interactive highlight.
    static let accent = Color(hex: 0x12A0FF)

    /// #000000 — Secondary/surface background.
    static let secondary = Color(hex: 0x000000)

    // MARK: - Text

    /// #FFFFFF — On-camera UI text, always white.
    static let textOnCamera = Color.white

    // MARK: - Gridline

    /// #D94A3D — Composition guide lines when NOT yet aligned.
    /// Use this when the scene/object detection shows the subject
    /// is not in the correct position for the chosen composition.
    static let gridlineRed = Color(hex: 0xD94A3D)

    /// #35C75A — Composition guide lines when the scene IS aligned.
    /// Use this when Vision analysis confirms the composition matches
    /// what is physically in the camera frame (object/scene based, not gyroscope).
    static let gridlineGreen = Color(hex: 0x35C75A)

    /// White at 60% — fallback when Vision has no data.
    /// Used when saliency / horizon / face detection has not yet returned results.
    static let gridlineWhite = Color.white.opacity(0.6)
}

// MARK: - Hex Init

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 08) & 0xFF) / 255,
            blue: Double((hex >> 00) & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - UIColor convenience (for Core Graphics rendering)

extension UIColor {
    static let gridlineRed = UIColor(Color(hex: 0xD94A3D))
    static let gridlineGreen = UIColor(Color(hex: 0x35C75A))
    static let gridlineWhite = UIColor.white.withAlphaComponent(0.6)
}
