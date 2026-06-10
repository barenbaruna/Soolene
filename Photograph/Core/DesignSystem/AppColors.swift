import SwiftUI

enum AppColors {
    // MARK: - Brand

    /// #EFC44F — Primary action color (golden yellow).
    /// Used for active states, selected lenses, active flash, and CTA elements.
    static let primary = Color(hex: 0xEFC44F)

    /// #12A0FF — Accent / interactive highlight.
    static let accent = Color(hex: 0x12A0FF)

    // MARK: - Surface

    /// #2C2C2E — Screen / Base background
    static let screen = Color(hex: 0x2C2C2E)

    /// Dark gallery surface used by camera-adjacent browsing flows.
    static let gallerySurface = screen

    // MARK: - Text

    /// #FFFFFF — On-camera UI text, always white.
    static let textOnCamera = Color(hex: 0xFFFFFF)

    // MARK: - Gridline

    /// #D94A3D — Composition guide lines when NOT yet aligned.
    static let gridlineRed = Color(hex: 0xD94A3D)

    /// #35C75A — Composition guide lines when the scene IS aligned.
    static let gridlineGreen = Color(hex: 0x35C75A)
    
    /// White at 60% — fallback when Vision has no data.
    static let gridlineWhite = Color.white.opacity(0.6)

    // MARK: - Phase Animation

    /// Golden glow behind subject bracket when locked.
    static let lockGlow = primary.opacity(0.3)

    /// Green glow behind merged checkmark on perfect alignment.
    static let perfectGlow = gridlineGreen.opacity(0.25)

    /// Subtle hint circles during scanning phase.
    static let scanningHint = Color.white.opacity(0.15)

    /// Selected composition pill tint.
    static let pickerSelected = primary.opacity(0.85)
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
