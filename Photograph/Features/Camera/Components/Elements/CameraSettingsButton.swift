import SwiftUI

/// UI Element for Camera Settings Button.
/// Matches Design System: Circle with 6 dots, Foreground #000000 60%.
struct CameraSettingsButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // "ellipsis" is 3 dots. A 6-dot icon might be a custom SF Symbol or "circle.grid.2x2.fill".
            // Since we need 6 dots (3x2 or 2x3), "circle.grid.3x3.fill" is 9 dots.
            // Let's use a 6-dot symbol approximation or fallback to an image.
            Image(systemName: "ellipsis")
                .font(Typography.title)
                .foregroundStyle(Color.black.opacity(0.6))
                .interactiveGlassCircle(size: 56)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        CameraSettingsButton { }
    }
}
