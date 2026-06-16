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
    @Environment(\.presentationMode) private var presentationMode
    @State private var viewModel = AppDependencies.shared.makeGalleryViewModel()
    @State private var selectedTab: GalleryTab = .recent

    enum GalleryTab {
        case recent
        case library
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
                        .frame(width: 240)

                        if viewModel.readPermission == .limited {
                            limitedAccessBanner
                                .padding(.horizontal, Spacing.standard)
                        }
                    }
                    .padding(.top, Spacing.small)
                    .padding(.bottom, Spacing.medium)
        NavigationStack {
            VStack(spacing: 0) {
                customHeader
                
                if viewModel.readPermission == .limited {
                    limitedAccessBanner
                        .padding(.horizontal, Spacing.standard)
                        .padding(.bottom, Spacing.small)
                }

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
                        ContentUnavailableView(
                            "No Photos Yet",
                            systemImage: "camera.viewfinder",
                            description: Text("Open the camera in \(AppIdentity.displayName) to start capturing guided compositions.")
                        )
                    } else {
                        if selectedTab == .recent {
                            recentContent
                        } else {
                            libraryInlineContent
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.startLocation.x < 30 && value.translation.width > 50 {
                            dismiss()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
            )
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .bottomBar)
            .toolbar(.hidden, for: .bottomBar)
            .task { await viewModel.bootstrap() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await viewModel.refresh() }
            }
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
        .preferredColorScheme(.light)
        .task {
            await viewModel.bootstrap()
        }
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(AppColors.secondary)
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: UIColor.white], for: .selected
            )
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: UIColor(AppColors.primary)], for: .normal
            )
            
            UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.primary)]
            UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(AppColors.primary)]
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await viewModel.refresh()
            }
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
        .padding(.bottom, Spacing.large)
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


}
