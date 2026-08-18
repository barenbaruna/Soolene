//
//  CompositionPhotoListView.swift
//  Soolene
//

import Photos
import SwiftUI

struct CompositionPhotoListView: View {
    @State private var viewModel: CompositionPhotoListViewModel
    @Environment(\.dismiss) private var dismiss

    init(composition: CompositionType) {
        _viewModel = State(
            initialValue: AppDependencies.shared.makeCompositionPhotoListViewModel(composition: composition)
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.primary)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .navigationTitle(viewModel.composition.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.primary)
                }
            }
        }
        .task { await viewModel.loadPhotos() }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(viewModel.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    NavigationLink {
                        PhotoDetailView(
                            assets: viewModel.assets,
                            currentIndex: index,
                            assetCompositionMap: Dictionary(uniqueKeysWithValues: viewModel.assets.map { ($0.localIdentifier, viewModel.composition) }),
                            onDelete: {
                                Task {
                                    await viewModel.loadPhotos()
                                }
                            }
                        )
                    } label: {
                        GeometryReader { cellGeo in
                            PhotoThumbnailView(asset: asset)
                                .frame(width: cellGeo.size.width, height: cellGeo.size.width * 1.05)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(AppColors.primary, lineWidth: 1)
                                )
                        }
                        .aspectRatio(1/1.05, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.top, Spacing.small)
        }
        .contentMargins(.bottom, 30, for: .scrollContent)
    }
}
