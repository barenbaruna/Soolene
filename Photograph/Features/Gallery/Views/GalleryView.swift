//
//  GalleryView.swift
//  Visula
//
//  Library home — Recent strip + Composition category grid.
//

import Photos
import SwiftUI
import UIKit

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var compositionCounts: [CompositionType: Int] = [:]
    @State private var previewAssets: [CompositionType: PHAsset] = [:]
    @State private var recentAsset: PHAsset?
    @State private var recentComposition: CompositionType = .ruleOfThirds
    @State private var isLoading = true
    @State private var readPermission: PermissionStatus = .notDetermined
    @State private var isRequestingPermission = false

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.standard),
        GridItem(.flexible(), spacing: Spacing.standard)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !readPermission.allowsPhotoBrowse {
                    PhotoLibraryPermissionView(
                        readStatus: readPermission,
                        isRequesting: isRequestingPermission,
                        onRequestAccess: { Task { await requestReadAccess() } },
                        onOpenSettings: { PrivacyPermissionService.openSettings() },
                        onManageLimited: { PrivacyPermissionService.presentLimitedLibraryPicker() }
                    )
                } else if compositionCounts.values.reduce(0, +) == 0 {
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
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(AppColors.secondary)
        .preferredColorScheme(.dark)
        .task { await bootstrap() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshAndLoad() }
        }
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if readPermission == .limited {
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
                .padding(.horizontal, Spacing.standard)
            }
            .padding(.top, Spacing.small)
        }
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
            if let asset = recentAsset {
                NavigationLink {
                    PhotoDetailView(asset: asset, composition: recentComposition)
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

    private func bootstrap() async {
        readPermission = PrivacyPermissionService.photoReadStatus()
        await refreshAndLoad()
    }

    private func refreshAndLoad() async {
        readPermission = PrivacyPermissionService.photoReadStatus()
        guard readPermission.allowsPhotoBrowse else {
            isLoading = false
            return
        }
        isLoading = true
        await loadData()
    }

    private func requestReadAccess() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        readPermission = await PrivacyPermissionService.requestPhotoReadAccess()
        if readPermission.allowsPhotoBrowse {
            await loadData()
        } else {
            isLoading = false
        }
    }

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
        let recent = await GalleryManager.shared.fetchAllPhotos()?.firstObject
        var recentComp = CompositionType.ruleOfThirds
        if let recent {
            let metadata = await GalleryManager.shared.fetchAllCompositionMetadata()
            if let match = metadata.first(where: { $0.assetIdentifier == recent.localIdentifier }) {
                recentComp = match.composition
            }
        }
        await MainActor.run {
            compositionCounts = counts
            previewAssets = previews
            recentAsset = recent
            recentComposition = recentComp
            isLoading = false
        }
    }
}
