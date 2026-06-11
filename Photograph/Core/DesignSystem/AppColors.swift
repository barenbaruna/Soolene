import SwiftUI

/// Brand and semantic colors from the C3Photograph design system.
enum AppColors {
    // MARK: - Brand

    /// #506139 — Shutter fill, primary brand (olive green).
    static let primary = Color(hex: 0x506139)

    /// #B6A71A — Active control highlight, zoom ticks, selected states (gold).
    static let secondary = Color(hex: 0xB6A71A)

    /// #12A0FF — Interactive accent (level indicator, tracking border).
    static let accent = Color(hex: 0x12A0FF)

    // MARK: - Surface

    /// #000000 — Camera chrome and library background.
    static let surface = Color(hex: 0x000000)

    static let screen = surface
    static let gallerySurface = surface

    // MARK: - Text

    /// #FFFFFF — On-camera labels and icons.
    static let textOnCamera = Color(hex: 0xFFFFFF)

    /// #BCB9B8 — Guidance copy, section labels.
    static let textGuide = Color(hex: 0xBCB9B8)

    // MARK: - Gridline

    static let gridlineRed = Color(hex: 0xD94A3D)
    static let gridlineGreen = Color(hex: 0x35C75A)
    static let gridlineWhite = Color.white.opacity(0.6)

    // MARK: - Phase Animation

    static let lockGlow = secondary.opacity(0.35)
    static let perfectGlow = gridlineGreen.opacity(0.25)
    static let scanningHint = Color.white.opacity(0.15)
    static let pickerSelected = secondary.opacity(0.9)

    /// Active toolbar icon tint (flash, timer, EV, aspect).
    static let controlActive = secondary
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
