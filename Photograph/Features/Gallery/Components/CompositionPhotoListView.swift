//
//  CompositionPhotoListView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Photos
import SwiftUI

/// 3-column photo grid filtered to a single composition category.
struct CompositionPhotoListView: View {
    let composition: CompositionType
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if assets.isEmpty {
                Text("No \(composition.rawValue) photos yet.")
                    .textStyle(Typography.body, color: .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            NavigationLink {
                                PhotoDetailView(asset: asset, composition: composition)
                            } label: {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        PhotoThumbnailView(asset: asset)
                                    }
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(composition.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPhotos() }
    }

    private func loadPhotos() async {
        let identifiers = await GalleryManager.shared.fetchPhotoIdentifiers(for: composition)
        guard !identifiers.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var result: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in result.append(asset) }
        // Newest first
        result.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        await MainActor.run {
            assets = result
            isLoading = false
        }
    }
}
