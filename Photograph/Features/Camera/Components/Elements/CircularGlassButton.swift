import SwiftUI

/// Reusable atomic component for circular glass buttons (e.g. Back, Grid, Flip).
/// Follows iOS 26 Liquid Glass behavior while satisfying the Figma Design System specs.
struct CircularGlassButton: View {
    let iconName: String
    let iconOpacity: Double
    let action: () -> Void
    
    // Default opacity for icons in the Design System is often 80% or 41%
    init(iconName: String, iconOpacity: Double = 0.8, action: @escaping () -> Void) {
        self.iconName = iconName
        self.iconOpacity = iconOpacity
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(Typography.headline) // Scalable icon size
                .foregroundStyle(Color.black.opacity(iconOpacity))
                .interactiveGlassCircle(size: 56)
        }
        .buttonStyle(.plain) // Prevent default button styling since we use interactive glass
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        HStack(spacing: 20) {
            CircularGlassButton(iconName: "chevron.left") { } // Back Button
            CircularGlassButton(iconName: "perspective") { } // Grid Button
            CircularGlassButton(iconName: "arrow.trianglehead.2.clockwise.rotate.90", iconOpacity: 0.41) { } // Flip Button
        }
    }
}
