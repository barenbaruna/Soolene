import SwiftUI

/// Atomic component for the "Analyzing..." label or guidance tip.
/// Matches Design System: Capsule, Subheadline/Regular/15.
struct CompositionLabel: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(Typography.subheadline)
            .foregroundStyle(AppColors.textOnCamera) // White text
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2), in: Capsule())
            .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        CompositionLabel(text: "Analyzing...")
    }
}
