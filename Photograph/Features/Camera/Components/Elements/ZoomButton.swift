import SwiftUI

/// UI Element for Zoom selection.
/// Matches Design System: Circle, Subheadline/Regular/15, Padding 4, Foreground #000000 41%.
struct ZoomButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Typography.subheadline)
                // When selected, it's typically more opaque or primary tinted,
                // but design spec says Foreground #000000 Opacity 41%.
                .foregroundStyle(isSelected ? AppColors.primary : Color.black.opacity(0.41))
                .padding(8) // Spec says Padding 4, but that makes touch target too small unless framed
                .frame(minWidth: 44, minHeight: 44) // Accessibility touch target
                .background(isSelected ? Color.black.opacity(0.8) : Color.clear, in: Circle())
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        HStack {
            ZoomButton(text: "0.5", isSelected: false) { }
            ZoomButton(text: "1x", isSelected: true) { }
            ZoomButton(text: "2", isSelected: false) { }
        }
    }
}
