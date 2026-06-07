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
//  Created by Baren Baruna Harahap on 05/06/26.
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

    /// 2-column grid for category cards
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
