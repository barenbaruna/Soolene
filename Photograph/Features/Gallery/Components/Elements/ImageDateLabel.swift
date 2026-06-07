import SwiftUI

/// Date & time pill for photo detail toolbar (.principal placement).
/// Uses native `.regularMaterial` capsule — matching Apple's gallery.
///
/// HIG §15.1: .regularMaterial for pill/badge backgrounds
/// HIG §2.2: .headline for primary, .caption for metadata
struct ImageDateLabel: View {
    let dateText: String
    let timeText: String

    var body: some View {
        VStack(spacing: 2) {
            Text(dateText)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(timeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        ImageDateLabel(dateText: "7 Jun", timeText: "17.42")
    }
}
