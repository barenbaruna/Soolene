import SwiftUI

/// Molecule component for the Camera Bottom Bar.
/// Matches Design System "Camera Button Complete":
/// - Jarak antara button = 70
/// - Jarak antara button dan sisi luar (kanan-kiri) = 28
/// - Jarak atas-bawah = 22
struct CameraBottomBarComplete: View {
    let onGalleryTap: () -> Void
    let onShutterTap: () -> Void
    let onFlipTap: () -> Void
    
    // For mocked thumbnail
    var thumbnailImage: Image? = nil
    
    var body: some View {
        HStack(spacing: 70) {
            // Gallery Thumbnail
            Button(action: onGalleryTap) {
                Group {
                    if let img = thumbnailImage {
                        img
                            .resizable()
                            .scaledToFill()
                    } else {
                        // Empty state / Placeholder
                        Color(UIColor.systemGray4)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            }
            .buttonStyle(.plain)
            
            // Shutter Button
            ShutterButton(action: onShutterTap)
            
            // Flip Button
            CircularGlassButton(
                iconName: "arrow.trianglehead.2.clockwise.rotate.90",
                iconOpacity: 0.41,
                action: onFlipTap
            )
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        // Background container just for layout visualization (optional depending on app design)
        .background(AppColors.screen.opacity(0.8))
    }
}

#Preview {
    CameraBottomBarComplete(
        onGalleryTap: {},
        onShutterTap: {},
        onFlipTap: {}
    )
}
