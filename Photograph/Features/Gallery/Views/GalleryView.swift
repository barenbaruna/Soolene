//
//  GalleryView.swift
//  Photograph
//
//  Gallery main screen — 2-column composition category cards.
//  Presented as fullScreenCover from CameraView.
//
//  HIG §7.1: NavigationStack mandatory
//  HIG §8.1: .toolbarTitleDisplayMode(.inline) + .toolbarRole(.editor) for leading title
//  HIG §4.3: Nav bar auto-gets Liquid Glass — do NOT override toolbarBackground
//  HIG §4.7: Button(role: .close) for dismiss
//
//  Uses Design System: Typography, Spacing, AppColors.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Photos
import SwiftUI

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var compositionCounts: [CompositionType: Int] = [:]
    @State private var previewAssets: [CompositionType: PHAsset] = [:]
    @State private var isLoading = true

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
                    ContentUnavailableView(
                        "No Photos Yet",
                        systemImage: "camera.viewfinder",
                        description: Text("Photos you take with Visula will appear here, organised by composition.")
                    )
                } else {
                    categoryGrid
                }
            }
            .background(AppColors.gallerySurface)
            .navigationTitle("Gallery")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(AppColors.primary)
        .preferredColorScheme(.dark)
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
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.small)
        }
        .background(AppColors.gallerySurface)
        .contentMargins(.bottom, 30, for: .scrollContent)
    }

    // MARK: - Data Loading

    private func loadData() async {
        let counts = await GalleryManager.shared.fetchCompositionCounts()
        var previews: [CompositionType: PHAsset] = [:]
        for type in CompositionType.allCases {
            let identifiers = await GalleryManager.shared.fetchPhotoIdentifiers(for: type)
            if let firstID = identifiers.first {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [firstID], options: nil)
                if let asset = result.firstObject { previews[type] = asset }
            }
        }
        await MainActor.run {
            compositionCounts = counts
            previewAssets = previews
            isLoading = false
        }
    }
}
