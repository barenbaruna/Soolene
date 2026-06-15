//
//  CompositionPhotoListView.swift
//  Photograph
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
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            customHeader
            
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
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadPhotos() }
    }

    private var customHeader: some View {
        HStack(spacing: Spacing.medium) {
            Group {
                if #available(iOS 26, *) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.glass)
                } else {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(white: 0.95))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text(viewModel.composition.rawValue)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.primary)
            
            Spacer()
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.medium)
        .background(Color.white)
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
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
                                .clipShape(RoundedRectangle(cornerRadius: 35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 35)
                                        .stroke(AppColors.secondary, lineWidth: 3)
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
