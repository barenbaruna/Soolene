//
//  GalleryView.swift
//  Soolene
//

import Photos
import SwiftUI
import UIKit

struct GalleryView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: Spacing.small) {
                        Picker("Tab", selection: $selectedTab) {
                            Text("Recent").tag(GalleryTab.recent)
                            Text("Library").tag(GalleryTab.library)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .scaleEffect(1.2)
                        .padding(.vertical, 4)

                        if viewModel.readPermission == .limited {
                            limitedAccessBanner
                                .padding(.horizontal, Spacing.standard)
                        }
                    }
                    .padding(.top, Spacing.small)
                    .padding(.bottom, Spacing.medium)

                    if viewModel.isLoading {
                        ProgressView("Loading…")
                            .tint(AppColors.primary)
                            .frame(maxWidth: .infinity, minHeight: 400)
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
                        VStack(spacing: 12) {
                            Spacer().frame(height: 80)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("No Photos Yet")
                                .font(.title2.bold())
                            Text("Open the camera in \(AppIdentity.displayName) to start capturing guided compositions.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer().frame(height: 80)
                        }
                    } else {
                        if selectedTab == .recent {
                            recentContent
                        } else {
                            libraryInlineContent
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width > 50 {
                                    dismiss()
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                    )
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: AppIcon.iconChevronLeft)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .bottomBar)
            .toolbar(.hidden, for: .bottomBar)
            .task { await bootstrapGallery() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await refreshGallery() }
            }
            .onChange(of: onboarding.walkthroughPhotoIdentifier) { _, _ in
                Task { await autoOpenOnboardingPhotoWhenReady() }
            }
            .navigationDestination(for: String.self) { route in
                navigationDestination(for: route)
            }
        }
        .tint(AppColors.primary)
        .preferredColorScheme(.light)
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(AppColors.primary)
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: UIColor.white], for: .selected
            )
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: UIColor(AppColors.primary)], for: .normal
            )
            
            UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.primary)]
            UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(AppColors.primary)]
        }
    }

    // MARK: - Library inline content (for single ScrollView)

    private var libraryInlineContent: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = (screenWidth - 48) / 2
        let cardHeight = cardWidth * 1.05

        return VStack(spacing: Spacing.large) {
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
                                .foregroundStyle(AppColors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Spacing.standard)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(assets, id: \.localIdentifier) { asset in
                                    NavigationLink(value: asset.localIdentifier) {
                                        PhotoThumbnailView(asset: asset)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(AppColors.primary, lineWidth: 1)
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
        .padding(.bottom, Spacing.large)
    }


    private var recentContent: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.allAssets, id: \.localIdentifier) { asset in
                NavigationLink(value: asset.localIdentifier) {
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
        .padding(.vertical, Spacing.small)
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
            if !assets.isEmpty || true { // always true to prevent destruction during dismiss animation
                PhotoDetailView(
                    assets: assets,
                    currentIndex: assets.firstIndex(where: { $0.localIdentifier == route }) ?? 0,
                    assetCompositionMap: viewModel.assetCompositionMap,
                    onDelete: {
                        Task { await viewModel.refresh() }
                    }
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
        "soolene-composition-list://\(composition.rawValue)"
    }

    private func compositionListType(from route: String) -> CompositionType? {
        let prefix = "soolene-composition-list://"
        guard route.hasPrefix(prefix) else { return nil }
        let rawValue = String(route.dropFirst(prefix.count))
        return CompositionType(rawValue: rawValue)
    }


}
