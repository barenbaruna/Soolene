import SwiftUI

/// UI Element for the Camera Shutter Button.
/// Matches Design System: Outer Circle (SystemGray2), Inner Circle (White, Border Primary).
struct ShutterButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer Circle
                Circle()
                    .fill(Color(UIColor.systemGray2))
                    .frame(width: 80, height: 80)
                
                // Inner Circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(AppColors.primary, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ShutterButton { }
    }
}
