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

    @Environment(OnboardingStore.self) private var onboarding
    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isShowingOverlay = false
    @State private var isShowingDeleteConfirmation = false
    @State private var walkthroughAnchors: [WalkthroughAnchorID: CGRect] = [:]

    var body: some View {
        ZStack {
            AppColors.gallerySurface.ignoresSafeArea()

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
                ProgressView().tint(AppColors.primary)
            }

            // Bottom: delete bar — glass capsule
            VStack {
                Spacer()
                deleteBar
            }

            // Walkthrough Overlay
            WalkthroughOverlayView(context: .detail, anchors: walkthroughAnchors)
        }
        .overlay {
            gridToggleWalkthroughAnchor
        }
        .onPreferenceChange(WalkthroughAnchorPreferenceKey.self) { walkthroughAnchors = $0 }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(composition.galleryLabel)
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
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
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

    /// Invisible anchor aligned with the navigation bar grid toggle.
    /// Manually computes the global rect because `.walkthroughAnchor()` cannot
    /// correctly report position when combined with `.position()` inside a GeometryReader.
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

    /// Small capsule delete button — bottom trailing
    private var deleteBar: some View {
        HStack {
            Spacer()
            Button {
                HapticManager.selection()
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(AppColors.controlActive)
                    .frame(width: ControlMetrics.iconButton, height: ControlMetrics.iconButton)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Photo")
            .disabled(!onboarding.allowsPhotoDelete)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.bottom, Spacing.standard)
    }

    private func toggleGridOverlay() {
        guard onboarding.allowsPhotoGridToggle else { return }
        HapticManager.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingOverlay.toggle()
        }
        onboarding.advanceAfterGridToggle(isShowingOverlay: isShowingOverlay)
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
