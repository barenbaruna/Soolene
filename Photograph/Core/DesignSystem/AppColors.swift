import SwiftUI

/// Brand and semantic colors from the C3Photograph design system.
///
/// Organized to match the Design System spec:
///   Color/Brand/Primary, Color/Brand/Secondary,
///   Color/Surface/Default, Color/Surface/TextGuide,
///   Color/Neutral/Text, Color/Neutral/GridlineGreen, Color/Neutral/GridlineRed
enum AppColors {

    // MARK: - Brand

    /// Color/Brand/Primary — #506139
    /// Shutter fill, primary brand (olive green).
    static let primary = Color(hex: 0x506139)

    /// Color/Brand/Secondary — #B6A71A
    /// Active control highlight, zoom ticks, selected states (gold).
    static let secondary = Color(hex: 0xB6A71A)

    // MARK: - Surface

    /// Color/Surface/Default — #000000
    /// Camera chrome and library background.
    static let surfaceDefault = Color(hex: 0x000000)

    /// Color/Surface/TextGuide — #BCB9B8
    /// Guidance copy, section labels.
    static let surfaceTextGuide = Color(hex: 0xBCB9B8)

    // MARK: - Neutral

    /// Color/Neutral/Text — #FFFFFF
    /// On-camera labels and icons.
    static let neutralText = Color(hex: 0xFFFFFF)

    /// Color/Neutral/GridlineGreen — #35C75A
    static let neutralGridlineGreen = Color(hex: 0x35C75A)

    /// Color/Neutral/GridlineRed — #D94A3D
    static let neutralGridlineRed = Color(hex: 0xD94A3D)

    // MARK: - Legacy Aliases (backward compatibility)

    static let surface = surfaceDefault
    static let screen = surfaceDefault
    static let gallerySurface = surfaceDefault
    static let textOnCamera = neutralText
    static let textGuide = surfaceTextGuide
    static let gridlineRed = neutralGridlineRed
    static let gridlineGreen = neutralGridlineGreen
    static let gridlineWhite = Color.white.opacity(0.6)

    // MARK: - Derived / Phase Animation

    /// #12A0FF — Interactive accent (level indicator, tracking border).
    /// Not in the design spec but used by app-specific controls.
    static let accent = Color(hex: 0x12A0FF)

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
