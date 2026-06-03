//
//  TipBannerView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

/// Displays the composition tip in a compact banner.
/// Used in camera settings tray or as a standalone tip card.
struct TipBannerView: View {
    let technique: CompositionTechnique?

    private var name: String {
        technique?.composition.rawValue ?? "Tip"
    }

    private var tip: String {
        technique?.tip ?? "Point your camera at a scene to get composition guidance."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(tip)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tipBannerBackground()
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.5), value: tip)
        .id(tip)
    }
}

private extension View {
    @ViewBuilder
    func tipBannerBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: .rect(cornerRadius: 16))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            TipBannerView(technique: CompositionTechnique(
                composition: .diagonal,
                tip: "Follow diagonal lines in the scene for dynamic energy."
            ))
            .padding(.bottom, 32)
        }
    }
}
