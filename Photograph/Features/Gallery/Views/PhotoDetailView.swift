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
    @State private var fullImage: UIImage?
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
                // 1) Header
                customHeader
                    .padding(.bottom, Spacing.small)

                // 2) Main Photo — takes remaining space but capped
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
                .opacity(isShowingDeleteConfirmation ? 0 : 1)
            }

            if isShowingDeleteConfirmation {
                customDeleteDialog
            }
            // Walkthrough Overlay
            WalkthroughOverlayView(context: .detail, anchors: walkthroughAnchors)
        }
        .onPreferenceChange(WalkthroughAnchorPreferenceKey.self) { walkthroughAnchors = $0 }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(currentComposition.galleryLabel)
        .toolbarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textOnCamera)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .disabled(!onboarding.allowsPhotoDetailExit)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleGridOverlay) {
                    Image(systemName: "square.grid.3x3")
                        .fontWeight(.medium)
                        .foregroundStyle(isShowingOverlay ? AppColors.surface : AppColors.controlActive)
                        .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
                        .background(
                            isShowingOverlay ? AnyShapeStyle(AppColors.controlActive) : AnyShapeStyle(Color.white.opacity(0.12)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isShowingOverlay ? "Hide Overlay" : "Show Overlay")
                .disabled(!onboarding.allowsPhotoGridToggle)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.light)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadFullImage() }
        .onChange(of: currentIndex) { _, _ in
            Task { await loadFullImage() }
        }
    }

    // MARK: - Main Photo Card

    private var mainPhotoCard: some View {
        Group {
            if let fullImage {
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: fullImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        if isShowingOverlay {
                            CompositionGridView(
                                composition: currentComposition,
                                rect: CGRect(origin: .zero, size: geo.size),
                                color: AppColors.gridlineGreen,
                                isPerfect: false,
                                showSubjectBox: false
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            } else {
                ProgressView()
                    .tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Trash Button

    private var trashButton: some View {
        Group {
            if #available(iOS 26, *) {
                Button {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.secondary)
                }
                .buttonStyle(.glass)
                .disabled(!onboarding.allowsPhotoDelete)
            } else {
                Button {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingDeleteConfirmation = true
                    }
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
                .buttonStyle(.plain)
                .disabled(!onboarding.allowsPhotoDelete)
            }
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

    // MARK: - Custom Header

    private var customHeader: some View {
    // MARK: - Delete Bar

    /// Invisible anchor aligned with the navigation bar grid toggle.
    /// Manually computes the global rect because `.walkthroughAnchor()` cannot
    /// correctly report position when combined with `.position()` inside a GeometryReader.
//     private var gridToggleWalkthroughAnchor: some View {
//         GeometryReader { geo in
//             let globalFrame = geo.frame(in: .global)
//             let buttonSize = ControlMetrics.compactIconButton
//             let centerX = geo.size.width - Spacing.standard - buttonSize / 2
//             let centerY = geo.safeAreaInsets.top + 22
//             let buttonGlobalRect = CGRect(
//                 x: globalFrame.minX + centerX - buttonSize / 2,
//                 y: globalFrame.minY + centerY - buttonSize / 2,
//                 width: buttonSize,
//                 height: buttonSize
//             )
//             Color.clear
//                 .preference(
//                     key: WalkthroughAnchorPreferenceKey.self,
//                     value: [.gridToggle: buttonGlobalRect]
//                 )
//         }
//         .allowsHitTesting(false)
//     }

    /// Small capsule delete button — bottom trailing
//     private var deleteBar: some View {
        HStack {
            // Back button
            backButton
                .disabled(!onboarding.allowsPhotoDetailExit)

            Spacer()

            // Date pill
            datePill

            Spacer()

            // Scope / grid overlay toggle
            scopeButton
                .walkthroughAnchor(.gridToggle)
                .disabled(!onboarding.allowsPhotoGridToggle)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.top, Spacing.small)
    }

    // MARK: - Header Sub-components

    private var backButton: some View {
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
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var datePill: some View {
        Group {
            if #available(iOS 26, *) {
                VStack(spacing: 2) {
                    Text(dateParts.date)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text(dateParts.time)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppColors.primary.opacity(0.7))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 24)
                .glassEffect(.regular, in: .capsule)
            } else {
                VStack(spacing: 2) {
                    Text(dateParts.date)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text(dateParts.time)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppColors.primary.opacity(0.7))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 24)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private var scopeButton: some View {
        Group {
            if #available(iOS 26, *) {
                if isShowingOverlay {
                    Button { toggleGridOverlay() } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button { toggleGridOverlay() } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.glass)
                }
            } else {
                Button { toggleGridOverlay() } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isShowingOverlay ? .white : AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background(isShowingOverlay ? AppColors.primary : Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(isShowingOverlay ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Thumbnail Carousel

    private var thumbnailCarousel: some View {
        GeometryReader { carouselGeo in
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
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .frame(minWidth: carouselGeo.size.width, alignment: .center)
            }
        }
        .frame(height: 50)
    }

    private var customDeleteDialog: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingDeleteConfirmation = false
                    }
                }

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Delete")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Are you sure you want to delete the photo from this app?")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.bottom, Spacing.medium)

                    Button {
                        deletePhoto()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingDeleteConfirmation = false
                        }
                    } label: {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFF453A))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(Spacing.large)
                .background(Color(hex: 0x1C1C1E).opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, Spacing.medium)
                .padding(.bottom, Spacing.large)
            }
        }
        .transition(.opacity)
    }
    private func toggleGridOverlay() {
        HapticManager.selection()
        let nextOverlayState = !isShowingOverlay
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingOverlay = nextOverlayState
        }
        onboarding.advanceAfterGridToggle(isShowingOverlay: nextOverlayState)
    }

    // MARK: - Helpers

    private var dateParts: (date: String, time: String) {
        guard let asset = currentAsset, let date = asset.creationDate else { return ("", "") }
        let df = DateFormatter(); df.dateFormat = "d MMM"
        let tf = DateFormatter(); tf.dateFormat = "HH.mm"
        return (df.string(from: date), tf.string(from: date))
    }

    private func loadFullImage() async {
        guard let asset = currentAsset else { return }
        let size = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: opts) { img, info in
            guard let img else { return }
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !degraded { Task { @MainActor in self.fullImage = img } }
            else if self.fullImage == nil { Task { @MainActor in self.fullImage = img } }
        }
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
                        Task { await loadFullImage() }
                    }
                }
            }
        }
    }
}
