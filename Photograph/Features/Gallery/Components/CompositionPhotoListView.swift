//
//  CompositionPhotoListView.swift
//  Photograph
//
//  3-column photo grid for a single composition category.
//  Pushed inside NavigationStack from GalleryView.
//
//  HIG §8.1: .toolbarTitleDisplayMode(.inline) + .toolbarRole(.editor)
//  HIG §4.3: Nav bar auto-gets Liquid Glass
//  HIG §6.1: Spacing.small (8pt) between grid items
//
//  Uses Design System: Typography, Spacing, AppRadius.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Photos
import SwiftUI

struct CompositionPhotoListView: View {
    let composition: CompositionType
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.tiny),
        GridItem(.flexible(), spacing: Spacing.tiny),
        GridItem(.flexible(), spacing: Spacing.tiny)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if assets.isEmpty {
                ContentUnavailableView(
                    "No \(composition.rawValue) Photos",
                    systemImage: "photo.stack",
                    description: Text("Photos taken with \(composition.rawValue) composition will appear here.")
                )
            } else {
                photoGrid
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(composition.rawValue)
        .toolbarTitleDisplayMode(.inline)
        .task { await loadPhotos() }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.tiny) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    NavigationLink {
                        PhotoDetailView(asset: asset, composition: composition)
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { PhotoThumbnailView(asset: asset) }
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.top, Spacing.small)
        }
        .contentMargins(.bottom, 30, for: .scrollContent)
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
        result.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        await MainActor.run { assets = result; isLoading = false }
    }
}
