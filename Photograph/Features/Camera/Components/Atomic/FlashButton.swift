import SwiftUI

/// Atomic component for the Flash Button.
/// Matches Design System: Inactive (bolt.slash.fill) vs Active (bolt.fill).
struct FlashButton: View {
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "bolt.fill" : "bolt.slash.fill")
                .font(Typography.headline)
                // Use Primary Color for active, or default for inactive
                .foregroundStyle(isActive ? AppColors.primary : Color.black.opacity(0.8))
                .frame(width: 56, height: 56)
                .background(isActive ? AppColors.primary.opacity(0.2) : Color.clear, in: Circle())
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        HStack(spacing: 20) {
            FlashButton(isActive: false) { }
            FlashButton(isActive: true) { }
        }
    }
}
