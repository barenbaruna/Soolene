import SwiftUI

// MARK: - Liquid Glass Modifiers

/// Reusable Liquid Glass view modifiers for camera overlay UI (iOS 26 HIG).
extension View {

    /// Frosted glass capsule for pills and tips.
    func glassPill() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    /// Frosted glass circle for icon buttons.
    func glassCircle(size: CGFloat = 56) -> some View {
        self
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
    }

    /// Frosted glass rounded rectangle for cards.
    func glassCard(cornerRadius: CGFloat = AppRadius.large) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Interactive glass pill.
    func interactiveGlassPill() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// Interactive glass circle.
    func interactiveGlassCircle(size: CGFloat = 56) -> some View {
        self
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    /// Full width liquid glass band for top/bottom camera controls.
    func liquidGlassBand() -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 0.5)
            }
    }
}
