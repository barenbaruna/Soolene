//
//  GalleryView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 01/06/26.
//

import Photos
import SwiftUI

/// In-app gallery that shows photos taken by Photograph.
/// Main view shows composition categories as cards.
/// Tapping a category shows a grid of photos with that composition.
struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var compositionCounts: [CompositionType: Int] = [:]
    @State private var allPhotos: PHFetchResult<PHAsset>?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading photos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if totalPhotoCount == 0 {
                    emptyState
                } else {
                    categoryGrid
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Total Count

    private var totalPhotoCount: Int {
        compositionCounts.values.reduce(0, +)
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(CompositionType.allCases) { type in
                    let count = compositionCounts[type] ?? 0
                    NavigationLink {
                        CompositionPhotoListView(composition: type)
                    } label: {
                        CompositionCategoryCard(
                            composition: type,
                            photoCount: count
                        )
                    }
                    .disabled(count == 0)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Photos Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Photos you take with Photograph\nwill appear here, organized by composition.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadData() async {
        let counts = await GalleryManager.shared.fetchCompositionCounts()
        let photos = await GalleryManager.shared.fetchAllPhotos()

        await MainActor.run {
            compositionCounts = counts
            allPhotos = photos
            isLoading = false
        }
    }
}

// MARK: - Composition Category Card

/// A card showing the composition type icon, name, and photo count.
struct CompositionCategoryCard: View {
    let composition: CompositionType
    let photoCount: Int

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: composition.symbolName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(photoCount > 0 ? .primary : .tertiary)
                .frame(height: 40)

            // Name
            Text(composition.rawValue)
                .font(.headline)
                .foregroundStyle(photoCount > 0 ? .primary : .secondary)

            // Count
            Text("\(photoCount) photos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .categoryCardBackground(hasPhotos: photoCount > 0)
    }
}

private extension View {
    @ViewBuilder
    func categoryCardBackground(hasPhotos: Bool) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: 16))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(hasPhotos
                        ? Color(.secondarySystemBackground)
                        : Color(.tertiarySystemBackground))
            )
        }
    }
}

// MARK: - Composition Photo List View

/// Grid of photos filtered by a specific composition type.
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
                Text("No photos with \(composition.rawValue)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            NavigationLink {
                                PhotoDetailView(asset: asset, composition: composition)
                            } label: {
                                PhotoThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(composition.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPhotos()
        }
    }

    private func loadPhotos() async {
        let identifiers = await GalleryManager.shared.fetchPhotoIdentifiers(for: composition)

        guard !identifiers.isEmpty else {
            await MainActor.run {
                assets = []
                isLoading = false
            }
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var result: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            result.append(asset)
        }

        // Sort newest first
        result.sort { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }

        await MainActor.run {
            assets = result
            isLoading = false
        }
    }
}

// MARK: - Photo Thumbnail View

/// Loads and displays a thumbnail for a PHAsset.
struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let size = CGSize(width: 200, height: 200)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        await MainActor.run { image = result }
    }
}
