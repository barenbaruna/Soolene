//
//  PhotoDetailView.swift
//  Soolene
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
    @State private var isDeletingPhoto = false
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
                Text(currentComposition.galleryLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .opacity(isShowingOverlay ? 1 : 0)
                    .padding(.vertical, 8)

                // 1) Main Photo — takes remaining space but capped
                mainPhotoCard
                    .padding(.horizontal, Spacing.small)
                    .scaleEffect(isDeletingPhoto ? 0.01 : 1.0)
                    .opacity(isDeletingPhoto ? 0 : 1.0)

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
                        Image(systemName: AppIcon.iconChevronLeft)
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
                    ZStack {
                        if isShowingOverlay {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 36, height: 36)
                        }
                        Image(systemName: AppIcon.iconPerspective)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isShowingOverlay ? Color.white : AppColors.primary)
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .clipShape(Circle())
                .walkthroughAnchor(.gridToggle)
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
                    isShowingOverlay: isShowingOverlay,
                    onDismiss: { dismiss() }
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
            Image(systemName: AppIcon.iconTrash)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.primary)
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
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
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
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, carouselGeo.size.width / 2 - 22)
            .scrollPosition(id: Binding(
                get: { currentIndex },
                set: { newIndex in
                    if let newIndex, newIndex != currentIndex {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            currentIndex = newIndex
                        }
                    }
                }
            ), anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: currentIndex)
        }
        .frame(height: 50)
    }

    // MARK: - Actions

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



    private func deletePhoto() {
        guard let assetToDelete = currentAsset else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSFastEnumeration)
        } completionHandler: { success, _ in
            if success {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isDeletingPhoto = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onDelete()
                        assetsList.remove(at: currentIndex)
                        
                        if assetsList.isEmpty {
                            dismiss()
                        } else {
                            if currentIndex >= assetsList.count {
                                currentIndex = assetsList.count - 1
                            }
                            
                            // Restore scale with animation for the next photo
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isDeletingPhoto = false
                            }
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
    var onDismiss: (() -> Void)? = nil

    @State private var image: UIImage?
    
    // Zoom & Pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Dismiss state
    @State private var dismissOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            if isShowingOverlay {
                                GeometryReader { imgGeo in
                                    CompositionGridView(
                                        composition: composition,
                                        fullRect: CGRect(origin: .zero, size: imgGeo.size),
                                    aspectRect: CGRect(origin: .zero, size: imgGeo.size),
                                        color: AppColors.gridlineGreen,
                                        isPerfect: false,
                                        showSubjectBox: false
                                    )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                } else {
                    ProgressView()
                        .tint(AppColors.primary)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .offset(y: dismissOffset.height)
            .opacity(1.0 - Double(max(dismissOffset.height, 0)) / 400.0)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let delta = value.magnification / lastScale
                        lastScale = value.magnification
                        scale = max(1.0, min(scale * delta, 5.0))
                        
                        let maxOff = maxOffset(for: scale, geoSize: geo.size, imageSize: image?.size ?? geo.size)
                        offset = CGSize(
                            width: min(max(offset.width, -maxOff.width), maxOff.width),
                            height: min(max(offset.height, -maxOff.height), maxOff.height)
                        )
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale <= 1.0 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        } else {
                            let maxOff = maxOffset(for: scale, geoSize: geo.size, imageSize: image?.size ?? geo.size)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = CGSize(
                                    width: min(max(offset.width, -maxOff.width), maxOff.width),
                                    height: min(max(offset.height, -maxOff.height), maxOff.height)
                                )
                                lastOffset = offset
                            }
                        }
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: scale > 1.0 ? 0 : 10000)
                    .onChanged { value in
                        if scale > 1.0 {
                            let proposedOffset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            
                            let maxOff = maxOffset(for: scale, geoSize: geo.size, imageSize: image?.size ?? geo.size)
                            
                            offset = CGSize(
                                width: min(max(proposedOffset.width, -maxOff.width), maxOff.width),
                                height: min(max(proposedOffset.height, -maxOff.height), maxOff.height)
                            )
                        }
                    }
                    .onEnded { value in
                        if scale > 1.0 {
                            lastOffset = offset
                        }
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onChanged { value in
                        if scale == 1.0 {
                            if dismissOffset != .zero || (value.translation.height > 0 && value.translation.height > abs(value.translation.width) * 1.5) {
                                dismissOffset = CGSize(width: 0, height: max(value.translation.height, 0))
                            }
                        }
                    }
                    .onEnded { value in
                        if scale == 1.0 {
                            if dismissOffset.height > 120 {
                                onDismiss?()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dismissOffset = .zero
                                }
                            }
                        }
                    }
            )
        }
        .onChange(of: dismissOffset) { _, newValue in
            if newValue == .zero && scale == 1.0 {
                lastOffset = .zero
                offset = .zero
            }
        }
        .onChange(of: asset.localIdentifier) { _, _ in
            image = nil
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            dismissOffset = .zero
        }
        .task(id: asset.localIdentifier) {
            await loadImage()
        }
    }
    
    private func maxOffset(for scale: CGFloat, geoSize: CGSize, imageSize: CGSize) -> CGSize {
        let imageAR = imageSize.width / imageSize.height
        let geoAR = geoSize.width / geoSize.height
        
        let renderedWidth: CGFloat
        let renderedHeight: CGFloat
        
        if imageAR > geoAR {
            renderedWidth = geoSize.width
            renderedHeight = geoSize.width / imageAR
        } else {
            renderedWidth = geoSize.height * imageAR
            renderedHeight = geoSize.height
        }
        
        let scaledWidth = renderedWidth * scale
        let scaledHeight = renderedHeight * scale
        
        let maxOffsetX = max(0, (scaledWidth - geoSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - geoSize.height) / 2)
        
        return CGSize(width: maxOffsetX, height: maxOffsetY)
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


