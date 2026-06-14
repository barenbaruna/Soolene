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
    @State private var navigationPath: [String] = []

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.standard),
        GridItem(.flexible(), spacing: Spacing.standard)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading…")
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
                    ContentUnavailableView(
                        "No Photos Yet",
                        systemImage: "camera.viewfinder",
                        description: Text("Open the camera in \(AppIdentity.displayName) to start capturing guided compositions.")
                    )
                } else {
                    libraryContent
                }
            }
            .background(AppColors.gallerySurface)
            .navigationTitle("Library")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                        .accessibilityLabel("Close Library")
                        .disabled(onboarding.isWalkthroughActive)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { identifier in
                if let asset = viewModel.asset(localIdentifier: identifier) {
                    PhotoDetailView(asset: asset, composition: viewModel.recentComposition)
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

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if viewModel.readPermission == .limited {
                    limitedAccessBanner
                        .padding(.horizontal, Spacing.standard)
                }

                sectionHeader("RECENT")

                recentStrip
                    .padding(.horizontal, Spacing.standard)

                sectionHeader("COMPOSITION")
                    .padding(.top, Spacing.small)

                LazyVGrid(columns: columns, spacing: Spacing.standard) {
                    ForEach(CompositionType.allCases) { type in
                        let count = viewModel.compositionCounts[type] ?? 0
                        if count > 0 {
                            NavigationLink {
                                CompositionPhotoListView(composition: type)
                            } label: {
                                CompositionCategoryCard(
                                    composition: type,
                                    count: count,
                                    previewAsset: viewModel.previewAssets[type]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Spacing.standard)
            }
            .padding(.top, Spacing.small)
        }
        .allowsHitTesting(onboarding.allowsGalleryBrowsing)
        .contentMargins(.bottom, Spacing.large, for: .scrollContent)
    }

    private var limitedAccessBanner: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "photo.badge.plus")
                .foregroundStyle(AppColors.controlActive)
            Text(PrivacyPermissionService.photoBrowseMessage(for: .limited))
                .font(.caption)
                .foregroundStyle(AppColors.textGuide)
            Spacer(minLength: 0)
            Button("Manage") {
                PrivacyPermissionService.presentLimitedLibraryPicker()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(Spacing.small)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private var recentStrip: some View {
        Group {
            if let asset = viewModel.recentAsset {
                NavigationLink {
                    PhotoDetailView(asset: asset, composition: viewModel.recentComposition)
                } label: {
                    Color.clear
                        .frame(height: 120)
                        .overlay { PhotoThumbnailView(asset: asset) }
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 120)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColors.textGuide)
            .textCase(.uppercase)
            .padding(.horizontal, Spacing.standard)
    }

    private func openRecentPhotoForWalkthroughIfNeeded() {
        guard onboarding.shouldAutoOpenRecentPhoto else { return }
        guard navigationPath.isEmpty else { return }
        guard let recentIdentifier = viewModel.recentAsset?.localIdentifier else { return }
        navigationPath = [recentIdentifier]
    }
}
