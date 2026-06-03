//
//  AspectRatioButton.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

/// A compact button that cycles through aspect ratio modes on tap.
struct AspectRatioButton: View {
    @Binding var selectedRatio: AspectRatioMode

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                cycleRatio()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: selectedRatio.symbolName)
                    .font(.body)
                    .foregroundStyle(.white)
                Text(selectedRatio.rawValue)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            .aspectRatioButtonBackground()
        }
        .accessibilityLabel("Aspect Ratio: \(selectedRatio.rawValue)")
        .accessibilityHint("Double tap to cycle aspect ratio")
    }

    private func cycleRatio() {
        let all = AspectRatioMode.allCases
        guard let idx = all.firstIndex(of: selectedRatio) else { return }
        let next = all.index(after: idx)
        selectedRatio = next < all.endIndex ? all[next] : all[all.startIndex]
    }
}

// MARK: - Background (availability-gated)

private extension View {
    @ViewBuilder
    func aspectRatioButtonBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive())
        } else {
            background(.regularMaterial, in: Circle())
        }
    }
}
