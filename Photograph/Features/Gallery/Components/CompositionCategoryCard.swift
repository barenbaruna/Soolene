//
//  CompositionCategoryCard.swift
//  Photograph
//

import Photos
import SwiftUI

/// Composition category tile with label above preview (design reference).
struct CompositionCategoryCard: View {
    let composition: CompositionType
    let count: Int
    let previewAsset: PHAsset?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(composition.galleryLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textGuide)
                .textCase(.uppercase)

            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let asset = previewAsset {
                        PhotoThumbnailView(asset: asset)
                    } else {
                        Rectangle().fill(Color.white.opacity(0.12))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .accessibilityLabel("\(composition.rawValue), \(count) photos")
    }
}
