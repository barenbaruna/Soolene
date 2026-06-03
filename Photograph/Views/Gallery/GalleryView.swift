//
//  GalleryView.swift
//  Photograph
//
//  Gallery flow:
//    1. Main screen  → Composition category cards (like Mid-Fi #7)
//                      Each card shows a preview thumbnail from that category.
//    2. Tap a card   → 3-column grid of photos in that composition (Mid-Fi #2)
//    3. Tap a photo  → PhotoDetailView (full-screen)
//
//  Created by Baren Baruna Harahap on 01/06/26.
//

import Photos
import SwiftUI

// MARK: - Gallery Main View

/// Main gallery screen. Shows composition categories as cards.
struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var compositionCounts: [CompositionType: Int] = [:]
    @State private var previewAssets: [CompositionType: PHAsset] = [:]
    @State private var isLoading = true

    // 2-column grid for category cards
    private let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if compositionCounts.values.reduce(0, +) == 0 {
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
        .task { await loadData() }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.small) {
                ForEach(CompositionType.allCases) { type in
                    let count = compositionCounts[type] ?? 0
                    if count > 0 {
                        NavigationLink {
                            CompositionPhotoListView(composition: type)
                        } label: {
                            CompositionCategoryCard(
                                composition: type,
                                count: count,
                                previewAsset: previewAssets[type]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.standard)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.standard) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Photos Yet")
                .textStyle(Typography.title)
            Text("Photos you take with Photograph\nwill appear here, organised by composition.")
                .textStyle(Typography.subheadline, color: .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadData() async {
        let counts = await GalleryManager.shared.fetchCompositionCounts()
        var previews: [CompositionType: PHAsset] = [:]

        // For each category, grab the newest photo to use as the card thumbnail
        for type in CompositionType.allCases {
            let identifiers = await GalleryManager.shared.fetchPhotoIdentifiers(for: type)
            if let firstID = identifiers.first {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [firstID], options: nil)
                if let asset = result.firstObject {
                    previews[type] = asset
                }
            }
        }

        await MainActor.run {
            compositionCounts = counts
            previewAssets = previews
            isLoading = false
        }
    }
}

// MARK: - Composition Category Card

/// Card showing a composition category, with a real photo preview and count.
private struct CompositionCategoryCard: View {
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
            .clipped() // Prevents the image from bleeding outside the square
            .overlay(alignment: .bottom) {
                // Gradient + label text constrained within the square bounds
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70) // Fixed height gradient so it doesn't cover the whole image

                    VStack(spacing: 2) {
                        Text(composition.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                        Text("\(count) photo\(count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, Spacing.small)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusStandard))
    }
}

// MARK: - Composition Photo List View

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
