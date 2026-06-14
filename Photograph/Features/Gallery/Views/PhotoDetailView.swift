//
//  PhotoDetailView.swift
//  Photograph
//
//  Full-screen photo viewer with composition overlay toggle.
//
//  HIG §8.1: Toolbar with .principal for date pill, .topBarTrailing for toggle
//  HIG §15.1: .regularMaterial for date capsule, .ultraThinMaterial for controls
//  HIG §12.4: .confirmationDialog for delete
//  HIG §4.6: .buttonStyle(.glass) for interactive buttons
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

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isShowingOverlay = false
    @State private var isShowingDeleteConfirmation = false

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

            VStack(spacing: Spacing.medium) {
                customHeader

                Group {
                    if let fullImage {
                        GeometryReader { geo in
                            let cardWidth = geo.size.width
                            let cardHeight = geo.size.height
                            
                            ZStack {
                                Image(uiImage: fullImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: cardWidth, height: cardHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 40))
                                
                                if isShowingOverlay {
                                    StaticOverlayView(composition: currentComposition, size: CGSize(width: cardWidth, height: cardHeight))
                                        .clipShape(RoundedRectangle(cornerRadius: 40))
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.medium)
                    } else {
                        ProgressView()
                            .tint(AppColors.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                thumbnailCarousel
                    .padding(.vertical, Spacing.small)

                HStack {
                    Spacer()
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
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.standard)
            }

            WalkthroughOverlayView(context: .detail)

            if isShowingDeleteConfirmation {
                customDeleteDialog
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

    private var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

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
            .overlay(
                Capsule().stroke(Color.black.opacity(0.1), lineWidth: 1)
            )

            Spacer()

            Button {
                HapticManager.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingOverlay.toggle()
                }
            } label: {
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
        .padding(.horizontal, Spacing.medium)
        .padding(.top, Spacing.small)
    }

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
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
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

    private func imageFitSize(image: UIImage, in containerSize: CGSize) -> CGSize {
        let r = image.size.width / image.size.height
        let cr = containerSize.width / containerSize.height
        return r > cr
            ? CGSize(width: containerSize.width, height: containerSize.width / r)
            : CGSize(width: containerSize.height * r, height: containerSize.height)
    }

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
