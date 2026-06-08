import SwiftUI

// MARK: - Liquid Glass Modifiers

/// Reusable Liquid Glass view modifiers for camera overlay UI.
/// Uses iOS 18 `.background(.regularMaterial)` as a fallback for iOS 26 `.glassEffect()`
/// due to SDK compilation limits.
extension View {
    
    /// Wraps content in a frosted glass capsule shape.
    func glassPill() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
    
    /// Wraps content in a frosted glass circle.
    func glassCircle(size: CGFloat = 56) -> some View {
        self
            .frame(width: size, height: size)
            .background(.regularMaterial, in: Circle())
    }
    
    /// Wraps content in a frosted glass rounded rectangle.
    func glassCard(cornerRadius: CGFloat = AppRadius.large) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Interactive glass pill (reacts to touches)
    func interactiveGlassPill() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
    
    /// Interactive glass circle (reacts to touches)
    func interactiveGlassCircle(size: CGFloat = 56) -> some View {
        self
            .frame(width: size, height: size)
            .background(.regularMaterial, in: Circle())
    }
    
    /// Full width liquid glass band for top/bottom camera controls
    func liquidGlassBand() -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 0.5)
            }
            // A subtle gradient or shadow could be added here for extra depth
    }
}
