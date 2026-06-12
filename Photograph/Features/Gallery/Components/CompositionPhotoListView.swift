//
//  CompositionPhotoListView.swift
//  Photograph
//

import Photos
import SwiftUI

struct CompositionPhotoListView: View {
    @State private var viewModel: CompositionPhotoListViewModel

    init(composition: CompositionType) {
        _viewModel = State(
            initialValue: AppDependencies.shared.makeCompositionPhotoListViewModel(composition: composition)
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.assets.isEmpty {
                ContentUnavailableView(
                    "No \(viewModel.composition.rawValue) Photos",
                    systemImage: "photo.stack",
                    description: Text("Photos taken with \(viewModel.composition.rawValue) composition will appear here.")
                )
            } else {
                photoGrid
            }
        }
        .background(AppColors.gallerySurface)
        .navigationTitle(viewModel.composition.galleryLabel)
        .toolbarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.loadPhotos() }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.tiny) {
                ForEach(viewModel.assets, id: \.localIdentifier) { asset in
                    NavigationLink {
                        PhotoDetailView(asset: asset, composition: viewModel.composition)
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
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.small)
        }
        .background(AppColors.gallerySurface)
        .contentMargins(.bottom, 30, for: .scrollContent)
    }
}
