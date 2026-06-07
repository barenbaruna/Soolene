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
    let asset: PHAsset
    let composition: CompositionType

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isShowingOverlay = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            // Photo + overlay
            if let fullImage {
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
                ProgressView().tint(.white)
            }

            // Bottom: delete bar — glass capsule
            VStack {
                Spacer()
                deleteBar
            }

            // Walkthrough Overlay
            WalkthroughOverlayView(context: .detail)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Back
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .padding(8)
//                        .background(.ultraThinMaterial, in: Circle())
//                        .tint(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            // Date pill — HIG §15.1 .regularMaterial
            ToolbarItem(placement: .principal) {
                ImageDateLabel(dateText: dateParts.date, timeText: dateParts.time)
            }
            // Grid toggle
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.2)) { isShowingOverlay.toggle() }
                } label: {
                    Image(systemName: "perspective")
                        .fontWeight(.medium)
                        .foregroundStyle(isShowingOverlay ? .black : AppColors.primary)
                        .padding(8)
                        .background(
                            isShowingOverlay ? AnyShapeStyle(AppColors.primary) : AnyShapeStyle(.ultraThinMaterial),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isShowingOverlay ? "Hide Overlay" : "Show Overlay")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deletePhoto() }
        } message: {
            Text("Are you sure you want to delete the photo from this app?")
        }
        .task { await loadFullImage() }
    }

    // MARK: - Delete Bar

    /// Small capsule delete button — bottom trailing
    private var deleteBar: some View {
        HStack {
            Spacer()
            Button {
                HapticManager.selection()
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                    .padding(Spacing.standard)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Photo")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.bottom, Spacing.standard)
    }

    // MARK: - Helpers

    private func imageFitSize(image: UIImage, in containerSize: CGSize) -> CGSize {
        let r = image.size.width / image.size.height
        let cr = containerSize.width / containerSize.height
        return r > cr
            ? CGSize(width: containerSize.width, height: containerSize.width / r)
            : CGSize(width: containerSize.height * r, height: containerSize.height)
    }

    private var dateParts: (date: String, time: String) {
        guard let date = asset.creationDate else { return ("", "") }
        let df = DateFormatter(); df.dateFormat = "d MMM"
        let tf = DateFormatter(); tf.dateFormat = "HH.mm"
        return (df.string(from: date), tf.string(from: date))
    }

    private func loadFullImage() async {
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
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
        } completionHandler: { success, _ in
            if success { DispatchQueue.main.async { dismiss() } }
        }
    }
}
