//
//  CompositionCategoryCard.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Photos
import SwiftUI

/// Card showing a composition category, with a real photo preview and count.
struct CompositionCategoryCard: View {
    let composition: CompositionType
    let count: Int
    let previewAsset: PHAsset?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // Background image
                if let asset = previewAsset {
                    PhotoThumbnailView(asset: asset)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
            }
            .clipped()
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: ControlMetrics.galleryThumbnail + Spacing.standard)

                    Text(composition.rawValue)
                        .font(Typography.headline)
                        .foregroundStyle(AppColors.primary)
                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                        .padding(.bottom, Spacing.small)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }
}
