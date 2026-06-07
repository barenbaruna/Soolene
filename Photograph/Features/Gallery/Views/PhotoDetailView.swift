//
//  PhotoDetailView.swift
//  Photograph
//
//  Full-screen photo viewer with:
//  - Navigation bar: date (title) + composition toggle (trailing)
//  - Bottom-right floating delete button
//  - Composition overlay toggle
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Photos
import SwiftUI

/// Full-screen photo detail view.
struct PhotoDetailView: View {
    let asset: PHAsset
    let composition: CompositionType

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isShowingOverlay = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let fullImage {
                // Photo with overlay
                GeometryReader { geo in
                    let imageSize = imageFitSize(image: fullImage, in: geo.size)
                    let imageOrigin = CGPoint(
                        x: (geo.size.width - imageSize.width) / 2,
                        y: (geo.size.height - imageSize.height) / 2
                    )

                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    // Composition overlay — positioned exactly over the image area
                    if isShowingOverlay {
                        StaticOverlayView(composition: composition, size: imageSize)
                            .position(
                                x: imageOrigin.x + imageSize.width / 2,
                                y: imageOrigin.y + imageSize.height / 2
                            )
                            .allowsHitTesting(false)
                    }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Bottom-right delete button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        HapticManager.selection()
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .padding(Spacing.standard)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Delete Photo")
                    .padding(.trailing, Spacing.medium)
                    .padding(.bottom, Spacing.large)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Centre: date & composition type
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(formattedDate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(composition.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Trailing: toggle composition overlay
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingOverlay.toggle()
                    }
                } label: {
                    Image(systemName: isShowingOverlay ? "rectangle.split.3x3.fill" : "rectangle.split.3x3")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(isShowingOverlay ? "Hide Overlay" : "Show Overlay")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete Photo",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete from App", role: .destructive) {
                deletePhoto()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this photo from the app?")
        }
        .task { await loadFullImage() }
    }

    // MARK: - Layout Helpers

    /// Calculates the displayed size of the image when using `.scaledToFit()`.
    private func imageFitSize(image: UIImage, in containerSize: CGSize) -> CGSize {
        let imageRatio = image.size.width / image.size.height
        let containerRatio = containerSize.width / containerSize.height

        if imageRatio > containerRatio {
            // Image is wider than container — width-constrained
            let width = containerSize.width
            let height = width / imageRatio
            return CGSize(width: width, height: height)
        } else {
            // Image is taller — height-constrained
            let height = containerSize.height
            let width = height * imageRatio
            return CGSize(width: width, height: height)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        guard let date = asset.creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Image Loading

    private func loadFullImage() async {
        let size = CGSize(
            width: CGFloat(asset.pixelWidth),
            height: CGFloat(asset.pixelHeight)
        )
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFit,
            options: options
        ) { img, info in
            guard let img else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded {
                Task { @MainActor in self.fullImage = img }
            } else if self.fullImage == nil {
                Task { @MainActor in self.fullImage = img }
            }
        }
    }

    // MARK: - Delete

    private func deletePhoto() {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
        } completionHandler: { success, _ in
            if success {
                DispatchQueue.main.async { dismiss() }
            }
        }
    }
}
