//
//  PhotoDetailView.swift
//  Photograph
//
//  Full-screen photo viewer with composition overlay toggle.
//
//  Uses Liquid Glass (iOS 26+) for header buttons, date pill, and delete dialog.
//  Falls back to manual styling for iOS < 26.
//
//  Uses Design System: Typography, Spacing, AppColors.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Photos
import SwiftUI

struct PhotoDetailView: View {
    let assetCompositionMap: [String: CompositionType]
    let onDelete: () -> Void

    @State private var assetsList: [PHAsset]
    @State private var currentIndex: Int

    @Environment(OnboardingStore.self) private var onboarding
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingOverlay = false
    @State private var isShowingDeleteConfirmation = false
    @State private var walkthroughAnchors: [WalkthroughAnchorID: CGRect] = [:]

    init(
        assets: [PHAsset],
        currentIndex: Int,
        assetCompositionMap: [String: CompositionType],
        onDelete: @escaping () -> Void
    ) {
        self._assetsList = State(initialValue: assets)
        self._currentIndex = State(initialValue: currentIndex)
        self.assetCompositionMap = assetCompositionMap
        self.onDelete = onDelete
    }

    private var currentAsset: PHAsset? {
        guard currentIndex < assetsList.count else { return nil }
        return assetsList[currentIndex]
    }

    private var currentComposition: CompositionType {
        guard let asset = currentAsset else { return .ruleOfThirds }
        return assetCompositionMap[asset.localIdentifier] ?? .ruleOfThirds
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // 1) Main Photo — takes remaining space but capped
                mainPhotoCard
                    .padding(.horizontal, Spacing.standard)

                Spacer(minLength: Spacing.small)

                // 3) Thumbnail carousel — centered, below photo
                thumbnailCarousel
                    .padding(.bottom, Spacing.small)

                // 4) Trash button — trailing, below carousel
                HStack {
                    Spacer()
                    trashButton
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.standard)
            }

            // Walkthrough Overlay
            WalkthroughOverlayView(context: .detail, anchors: walkthroughAnchors)
        }
        .overlay {
            gridToggleWalkthroughAnchor
        }
        .onPreferenceChange(WalkthroughAnchorPreferenceKey.self) { walkthroughAnchors = $0 }
        .navigationBarBackButtonHidden(true)

        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
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
                .disabled(!onboarding.allowsPhotoDetailExit)
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(dateParts.date)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text(dateParts.time)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppColors.primary.opacity(0.7))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    toggleGridOverlay()
                }) {
                    Image(systemName: "scope")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isShowingOverlay ? AppColors.secondary : AppColors.primary)
                }
                .disabled(!onboarding.allowsPhotoGridToggle)
            }
        }
    }

    // MARK: - Main Photo Card

    private var mainPhotoCard: some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<assetsList.count, id: \.self) { index in
                let asset = assetsList[index]
                let composition = assetCompositionMap[asset.localIdentifier] ?? .ruleOfThirds
                PhotoPageView(
                    asset: asset,
                    composition: composition,
                    isShowingOverlay: isShowingOverlay
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: - Trash Button

    private var trashButton: some View {
        Button {
            HapticManager.selection()
            isShowingDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.secondary)
                .frame(width: 48, height: 48)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
        }
        .disabled(!onboarding.allowsPhotoDelete)
        .popover(isPresented: $isShowingDeleteConfirmation, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Delete")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Are you sure you want to delete the photo from this app?")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .padding(.bottom, 4)

                Button {
                    deletePhoto()
                    isShowingDeleteConfirmation = false
                } label: {
                    Text("Delete")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(width: 250)
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Walkthrough Anchor

    /// Invisible anchor aligned with the header grid toggle button.
    private var gridToggleWalkthroughAnchor: some View {
        GeometryReader { geo in
            let globalFrame = geo.frame(in: .global)
            let buttonSize = ControlMetrics.compactIconButton
            let centerX = geo.size.width - Spacing.standard - buttonSize / 2
            let centerY = geo.safeAreaInsets.top + 22
            let buttonGlobalRect = CGRect(
                x: globalFrame.minX + centerX - buttonSize / 2,
                y: globalFrame.minY + centerY - buttonSize / 2,
                width: buttonSize,
                height: buttonSize
            )
            Color.clear
                .preference(
                    key: WalkthroughAnchorPreferenceKey.self,
                    value: [.gridToggle: buttonGlobalRect]
                )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Thumbnail Carousel

    private var thumbnailCarousel: some View {
        GeometryReader { carouselGeo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<assetsList.count, id: \.self) { index in
                            let asset = assetsList[index]
                            let isSelected = currentIndex == index
                            Button {
                                HapticManager.selection()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    currentIndex = index
                                }
                            } label: {
                                PhotoThumbnailView(asset: asset)
                                    .frame(width: isSelected ? 44 : 28, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? AppColors.secondary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, Spacing.medium)
                    .frame(minWidth: carouselGeo.size.width, alignment: .center)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 50)
    }

    // MARK: - Actions

    private func toggleGridOverlay() {
        HapticManager.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingOverlay.toggle()
        }
    }

    // MARK: - Helpers

    private var dateParts: (date: String, time: String) {
        guard let asset = currentAsset, let date = asset.creationDate else { return ("", "") }
        let df = DateFormatter(); df.dateFormat = "d MMM"
        let tf = DateFormatter(); tf.dateFormat = "HH.mm"
        return (df.string(from: date), tf.string(from: date))
    }



    private func deletePhoto() {
        guard let assetToDelete = currentAsset else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSFastEnumeration)
        } completionHandler: { success, _ in
            if success {
                DispatchQueue.main.async {
                    onDelete()
                    assetsList.remove(at: currentIndex)
                    if assetsList.isEmpty {
                        dismiss()
                    } else {
                        if currentIndex >= assetsList.count {
                            currentIndex = assetsList.count - 1
                        }
                    }
                }
            }
        }
    }
}

struct PhotoPageView: View {
    let asset: PHAsset
    let composition: CompositionType
    let isShowingOverlay: Bool

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    if isShowingOverlay {
                        CompositionGridView(
                            composition: composition,
                            rect: CGRect(origin: .zero, size: geo.size),
                            color: AppColors.gridlineGreen,
                            isPerfect: false,
                            showSubjectBox: false
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    ProgressView()
                        .tint(AppColors.primary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 40))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        let size = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: opts) { img, info in
            guard let img else { return }
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !degraded { Task { @MainActor in self.image = img } }
            else if self.image == nil { Task { @MainActor in self.image = img } }
        }
    }
}
