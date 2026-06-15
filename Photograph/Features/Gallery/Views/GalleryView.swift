//
//  GalleryView.swift
//  Photograph
//

import Photos
import SwiftUI
import UIKit

struct GalleryView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AppDependencies.shared.makeGalleryViewModel()
    @State private var selectedTab: GalleryTab = .recent
    @State private var navigationPath: [String] = []

    enum GalleryTab {
        case recent
        case library
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                customHeader
                
                if viewModel.readPermission == .limited {
                    limitedAccessBanner
                        .padding(.horizontal, Spacing.standard)
                        .padding(.bottom, Spacing.small)
                }

                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading…")
                            .tint(AppColors.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !viewModel.readPermission.allowsPhotoBrowse {
                        PhotoLibraryPermissionView(
                            readStatus: viewModel.readPermission,
                            isRequesting: viewModel.isRequestingPermission,
                            onRequestAccess: { 
                              Task {
                                  await viewModel.requestReadAccess()
                                  openRecentPhotoForWalkthroughIfNeeded()
                              }
                            },
                            onOpenSettings: { PrivacyPermissionService.openSettings() },
                            onManageLimited: { PrivacyPermissionService.presentLimitedLibraryPicker() }
                        )
                    } else if viewModel.isLibraryEmpty {
                        let desc = "Open the camera in " + AppIdentity.displayName + " to start capturing guided compositions."
                        ContentUnavailableView(
                            "No Photos Yet",
                            systemImage: "camera.viewfinder",
                            description: Text(desc)
                        )
                    } else {
                        if selectedTab == .recent {
                            VStack(spacing: 0) {
                                recentContent
                                Spacer()
                            }
                        } else {
                            libraryContent
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
            .background(Color.white)
            .preferredColorScheme(.light)
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.bootstrap() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await viewModel.refresh() }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { identifier in
                if let idx = viewModel.allAssets.firstIndex(where: { $0.localIdentifier == identifier }) {
                    PhotoDetailView(
                        assets: viewModel.allAssets,
                        currentIndex: idx,
                        assetCompositionMap: viewModel.assetCompositionMap,
                        onDelete: {
                            Task { await viewModel.refresh() }
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Photo Unavailable",
                        systemImage: "photo",
                        description: Text("The guided photo could not be opened.")
                    )
                }
            }
        }
        .tint(AppColors.secondary)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.bootstrap()
            openRecentPhotoForWalkthroughIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await viewModel.refresh()
                openRecentPhotoForWalkthroughIfNeeded()
            }
        }
        .onChange(of: viewModel.recentAsset?.localIdentifier) { _, _ in
            openRecentPhotoForWalkthroughIfNeeded()
        }
    }

    private var customHeader: some View {
        VStack(spacing: Spacing.medium) {
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
                
                Text("Collections")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                
                Spacer()
            }
            .padding(.horizontal, Spacing.standard)
            
            // Custom sliding Segmented Control (Native iOS Liquid Glass design)
            segmentedControl
        }
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.medium)
        .background(Color.white)
    }

    private var segmentedControl: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Recent").tag(GalleryTab.recent)
            Text("Library").tag(GalleryTab.library)
        }
        .pickerStyle(.segmented)
        .frame(width: 240)
    }

    private var recentContent: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = (screenWidth - 48) / 2
        let cardHeight = cardWidth * 1.05
        let recentRows = [
            GridItem(.fixed(cardHeight), spacing: Spacing.standard),
            GridItem(.fixed(cardHeight), spacing: Spacing.standard),
            GridItem(.fixed(cardHeight), spacing: Spacing.standard)
        ]
        
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: recentRows, spacing: 12) {
                ForEach(Array(viewModel.allAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    NavigationLink {
                        PhotoDetailView(
                            assets: viewModel.allAssets,
                            currentIndex: index,
                            assetCompositionMap: viewModel.assetCompositionMap,
                            onDelete: {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                        )
                    } label: {
                        PhotoThumbnailView(asset: asset)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 35)
                                    .stroke(AppColors.secondary, lineWidth: 3)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.small)
        }
        .frame(height: cardHeight * 3 + 40)
    }

    private var libraryContent: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = (screenWidth - 48) / 2
        let cardHeight = cardWidth * 1.05
        
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.large) {
                ForEach(CompositionType.allCases) { type in
                    let assets = viewModel.assetsByComposition[type] ?? []
                    if !assets.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Text(type.rawValue)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppColors.primary)
                            
                            Spacer()
                            
                            NavigationLink {
                                CompositionPhotoListView(composition: type)
                            } label: {
                                HStack(spacing: 2) {
                                    Text("show all")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Spacing.standard)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                    NavigationLink {
                                        PhotoDetailView(
                                            assets: assets,
                                            currentIndex: index,
                                            assetCompositionMap: viewModel.assetCompositionMap,
                                            onDelete: {
                                                Task {
                                                    await viewModel.refresh()
                                                }
                                            }
                                        )
                                    } label: {
                                        PhotoThumbnailView(asset: asset)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 35))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 35)
                                                    .stroke(AppColors.secondary, lineWidth: 3)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.standard)
                        }
                        .frame(height: cardHeight + 6)
                    }
                }
                }
            }
            .padding(.top, Spacing.small)
        }
        .allowsHitTesting(onboarding.allowsGalleryBrowsing)
        .contentMargins(.bottom, Spacing.large, for: .scrollContent)
    }

    private var limitedAccessBanner: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "photo.badge.plus")
                .foregroundStyle(AppColors.primary)
            Text(PrivacyPermissionService.photoBrowseMessage(for: .limited))
                .font(.caption)
                .foregroundStyle(AppColors.primary.opacity(0.8))
            Spacer(minLength: 0)
            Button("Manage") {
                PrivacyPermissionService.presentLimitedLibraryPicker()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.primary)
        }
        .padding(Spacing.small)
        .background {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(Color.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.small))
            } else {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(Color.black.opacity(0.05))
            }
        }
    }

    private func openRecentPhotoForWalkthroughIfNeeded() {
        guard onboarding.shouldAutoOpenRecentPhoto else { return }
        guard navigationPath.isEmpty else { return }
        guard let recentIdentifier = viewModel.recentAsset?.localIdentifier else { return }
        navigationPath = [recentIdentifier]
    }
}
