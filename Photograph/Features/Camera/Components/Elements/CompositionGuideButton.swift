import SwiftUI

/// UI Element for the text-based guidance (e.g. "Align the object with horizontal guide lines").
/// Matches Design System: Capsule, Body/Regular/17, Foreground #000000 Opacity 60%.
struct CompositionGuideButton: View {
    let text: String
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: { action?() }) {
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Color.black.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        CompositionGuideButton(text: "Align the object with horizontal guide lines", action: nil)
    }
}
