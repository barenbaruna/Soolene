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
    @State private var hasAutoOpenedOnboardingPhoto = false

    let initialPhotoIdentifier: String?

    enum GalleryTab {
        case recent
        case library
    }

    init(initialPhotoIdentifier: String? = nil) {
        self.initialPhotoIdentifier = initialPhotoIdentifier
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
            .task { await bootstrapGallery() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await refreshGallery() }
            }
            .onChange(of: onboarding.walkthroughPhotoIdentifier) { _, _ in
                Task { await autoOpenOnboardingPhotoWhenReady() }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { route in
                navigationDestination(for: route)
            }
        }
        .tint(AppColors.secondary)
        .preferredColorScheme(.dark)
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
                ForEach(viewModel.allAssets, id: \.localIdentifier) { asset in
                    NavigationLink(value: asset.localIdentifier) {
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
                            
                            NavigationLink(value: compositionListRoute(for: type)) {
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
                                ForEach(assets, id: \.localIdentifier) { asset in
                                    NavigationLink(value: asset.localIdentifier) {
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

    @ViewBuilder
    private func navigationDestination(for route: String) -> some View {
        if let composition = compositionListType(from: route) {
            CompositionPhotoListView(composition: composition)
        } else {
            let assets = photoDetailAssets(for: route)
            if let idx = assets.firstIndex(where: { $0.localIdentifier == route }) {
                PhotoDetailView(
                    assets: assets,
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

    @MainActor
    private func bootstrapGallery() async {
        await viewModel.bootstrap()
        await autoOpenOnboardingPhotoWhenReady()
    }

    @MainActor
    private func refreshGallery() async {
        await viewModel.refresh()
        await autoOpenOnboardingPhotoWhenReady()
    }

    @MainActor
    private func autoOpenOnboardingPhotoWhenReady() async {
        guard onboarding.shouldAutoOpenRecentPhoto, !hasAutoOpenedOnboardingPhoto else { return }

        for attempt in 0..<10 {
            if autoOpenOnboardingPhotoIfPossible(allowFallbackToRecent: attempt == 9) {
                return
            }

            guard attempt < 9 else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            await viewModel.refresh()
        }
    }

    @MainActor
    private func autoOpenOnboardingPhotoIfPossible(allowFallbackToRecent: Bool) -> Bool {
        guard navigationPath.isEmpty else { return false }
        let identifier = onboarding.walkthroughPhotoIdentifier
            ?? initialPhotoIdentifier
            ?? (allowFallbackToRecent ? viewModel.recentAsset?.localIdentifier : nil)
        guard let identifier,
              viewModel.allAssets.contains(where: { $0.localIdentifier == identifier })
        else {
            return false
        }

        hasAutoOpenedOnboardingPhoto = true
        navigationPath = [identifier]
        return true
    }

    private func photoDetailAssets(for identifier: String) -> [PHAsset] {
        guard selectedTab == .library,
              let composition = viewModel.assetCompositionMap[identifier],
              let compositionAssets = viewModel.assetsByComposition[composition],
              compositionAssets.contains(where: { $0.localIdentifier == identifier })
        else {
            return viewModel.allAssets
        }

        return compositionAssets
    }

    private func compositionListRoute(for composition: CompositionType) -> String {
        "photograph-composition-list://\(composition.rawValue)"
    }

    private func compositionListType(from route: String) -> CompositionType? {
        let prefix = "photograph-composition-list://"
        guard route.hasPrefix(prefix) else { return nil }
        let rawValue = String(route.dropFirst(prefix.count))
        return CompositionType(rawValue: rawValue)
    }


}
