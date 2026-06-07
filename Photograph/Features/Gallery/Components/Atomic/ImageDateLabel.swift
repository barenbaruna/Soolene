import SwiftUI

/// Atomic component for showing image date and time in Gallery.
/// Matches Design System: Capsule, Button/Semibold/17 & Caption/Regular/12,
/// Foreground #000000 80%, Liquid Glass.
struct ImageDateLabel: View {
    let dateText: String
    let timeText: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dateText)
                .font(Typography.buttonCTA) // Semibold 17
                .foregroundStyle(AppColors.primary) // Example uses yellow text
            
            Text(timeText)
                .font(Typography.caption) // Regular 12
                .foregroundStyle(AppColors.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8), in: Capsule())
        .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        ImageDateLabel(dateText: "23 May", timeText: "15.20")
    }
}
