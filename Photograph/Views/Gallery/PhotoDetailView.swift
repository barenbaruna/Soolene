//
//  PhotoDetailView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 01/06/26.
//

import Photos
import SwiftUI

/// Full-screen photo detail view with composition overlay toggle and metadata.
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
                // Photo
                Image(uiImage: fullImage)
                    .resizable()
                    .scaledToFit()

                // Composition overlay (toggle)
                if isShowingOverlay {
                    GeometryReader { geo in
                        StaticOverlayView(
                            composition: composition,
                            size: geo.size
                        )
                    }
                    .allowsHitTesting(false)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(composition.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingOverlay.toggle()
                } label: {
                    Image(systemName: isShowingOverlay ? "grid.circle.fill" : "grid.circle")
                        .font(.title3)
                }
                .accessibilityLabel(isShowingOverlay ? "Hide Overlay" : "Show Overlay")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Delete Photo", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("Remove this photo from the Photograph album?")
        }
        .task {
            await loadFullImage()
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

    private func loadFullImage() async {
        let size = CGSize(
            width: CGFloat(asset.pixelWidth),
            height: CGFloat(asset.pixelHeight)
        )
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        await MainActor.run { fullImage = result }
    }

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

// MARK: - Static Overlay View (for photo review)

/// A simple SwiftUI-drawn overlay for viewing composition lines on saved photos.
struct StaticOverlayView: View {
    let composition: CompositionType
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let lineColor = Color.white.opacity(0.5)

            switch composition {
            case .ruleOfThirds:
                drawRuleOfThirds(context: &context, rect: rect, color: lineColor)
            case .center:
                drawCenter(context: &context, rect: rect, color: lineColor)
            case .horizontal:
                drawHorizontal(context: &context, rect: rect, color: lineColor)
            case .vertical:
                drawVertical(context: &context, rect: rect, color: lineColor)
            case .diagonal:
                drawDiagonal(context: &context, rect: rect, color: lineColor)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Drawing Methods

    private func drawRuleOfThirds(context: inout GraphicsContext, rect: CGRect, color: Color) {
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3

        for i in 1...2 {
            let x = thirdW * CGFloat(i)
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            context.stroke(path, with: .color(color), lineWidth: 0.8)
        }

        for i in 1...2 {
            let y = thirdH * CGFloat(i)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            context.stroke(path, with: .color(color), lineWidth: 0.8)
        }

        // Power points
        let dotColor = Color.yellow.opacity(0.6)
        for col in 1...2 {
            for row in 1...2 {
                let x = thirdW * CGFloat(col)
                let y = thirdH * CGFloat(row)
                let dotRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
            }
        }
    }

    private func drawCenter(context: inout GraphicsContext, rect: CGRect, color: Color) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 30

        // Circle
        let circlePath = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        context.stroke(circlePath, with: .color(color), lineWidth: 1.0)

        // Crosshair
        let crossLen: CGFloat = 12
        var hPath = Path()
        hPath.move(to: CGPoint(x: center.x - crossLen, y: center.y))
        hPath.addLine(to: CGPoint(x: center.x + crossLen, y: center.y))
        context.stroke(hPath, with: .color(color), lineWidth: 1.0)

        var vPath = Path()
        vPath.move(to: CGPoint(x: center.x, y: center.y - crossLen))
        vPath.addLine(to: CGPoint(x: center.x, y: center.y + crossLen))
        context.stroke(vPath, with: .color(color), lineWidth: 1.0)
    }

    private func drawHorizontal(context: inout GraphicsContext, rect: CGRect, color: Color) {
        for fraction in [0.33, 0.5, 0.67] as [CGFloat] {
            let y = rect.height * fraction
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            context.stroke(path, with: .color(color), lineWidth: 0.8)
        }
    }

    private func drawVertical(context: inout GraphicsContext, rect: CGRect, color: Color) {
        for fraction in [0.33, 0.5, 0.67] as [CGFloat] {
            let x = rect.width * fraction
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            context.stroke(path, with: .color(color), lineWidth: 0.8)
        }
    }

    private func drawDiagonal(context: inout GraphicsContext, rect: CGRect, color: Color) {
        var path1 = Path()
        path1.move(to: CGPoint(x: 0, y: 0))
        path1.addLine(to: CGPoint(x: rect.width, y: rect.height))
        context.stroke(path1, with: .color(color), lineWidth: 0.8)

        var path2 = Path()
        path2.move(to: CGPoint(x: rect.width, y: 0))
        path2.addLine(to: CGPoint(x: 0, y: rect.height))
        context.stroke(path2, with: .color(color), lineWidth: 0.8)
    }
}
