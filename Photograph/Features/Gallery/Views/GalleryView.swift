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

    enum GalleryTab {
        case recent
        case library
    }

    var body: some View {
        NavigationStack {
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
                              }
                            },
                            onOpenSettings: { PrivacyPermissionService.openSettings() },
                            onManageLimited: { PrivacyPermissionService.presentLimitedLibraryPicker() }
                        )
                    } else if viewModel.isLibraryEmpty {
                        ContentUnavailableView(
                            "No Photos Yet",
                            systemImage: "camera.viewfinder",
                            description: Text("Open the camera in \(AppIdentity.displayName) to start capturing guided compositions.")
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
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }

    private var customHeader: some View {
        VStack(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                Button {
                    dismiss()
                } label: {
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
                
                Text("Collections")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                
                Spacer()
            }
            .padding(.horizontal, Spacing.standard)
            
            // Custom sliding Segmented Control (Native iOS Liquid Glass design)
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTab = .recent
                    }
                } label: {
                    Text("Recent")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedTab == .recent ? AppColors.primary : Color(hex: 0x8E8E93))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTab = .library
                    }
                } label: {
                    Text("Library")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedTab == .library ? AppColors.primary : Color(hex: 0x8E8E93))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
            }
            .background {
                GeometryReader { geo in
                    let width = geo.size.width / 2
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .frame(width: width, height: geo.size.height)
                        .offset(x: selectedTab == .recent ? 0 : width)
                }
            }
            .clipShape(Capsule())
            .glassEffect(.regular, in: .capsule)
            .frame(width: 240)
        }
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.medium)
        .background(Color.white)
    }

    private var recentContent: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = (screenWidth - 48) / 2
        let cardHeight = cardWidth * 1.25
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
        let cardHeight = cardWidth * 1.25
        
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.large) {
                ForEach(CompositionType.allCases) { type in
                    let assets = viewModel.assetsByComposition[type] ?? []
                    
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
                                if assets.isEmpty {
                                    RoundedRectangle(cornerRadius: 35)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                        .frame(width: cardWidth, height: cardHeight)
                                        .overlay {
                                            VStack(spacing: 4) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.title2)
                                                    .foregroundStyle(Color.gray)
                                                Text("No photos")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.gray)
                                            }
                                        }
                                } else {
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
                            }
                            .padding(.horizontal, Spacing.standard)
                        }
                        .frame(height: cardHeight + 6)
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
        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: AppRadius.small))
    }


}
