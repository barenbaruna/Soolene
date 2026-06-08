import SwiftUI

/// UI Element for Camera Settings Button.
/// Matches Design System: Circle with 6 dots, Foreground #000000 60%.
struct CameraSettingsButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
