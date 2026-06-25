//
//  CameraPreviewLayer.swift
//  Soolene
//

import SwiftUI

/// Rear spatial or front classic camera preview with gesture handlers.
struct CameraPreviewLayer: View {
    let viewModel: CameraViewModel
    let onFocusTap: ((CGPoint, CGPoint) -> Void)?
    let onSubjectPin: ((CGPoint, CGPoint) -> Void)?
    let onClearPin: (() -> Void)?
    var allowsZoomGestures = true

    var body: some View {
        GeometryReader { proxy in
            let previewRect = viewModel.selectedAspectRatio.cropRect(in: proxy.size)

            ZStack {
                backgroundPreview
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                previewSurface(in: previewRect)
                    .frame(width: previewRect.width, height: previewRect.height)
                    .position(x: previewRect.midX, y: previewRect.midY)
            }
        }
        .ignoresSafeArea()
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        if viewModel.cameraMode == .rearSpatial {
            SpatialCameraView(
                engine: viewModel.spatialEngine,
                previewZoom: viewModel.rearSpatialPreviewVisualZoom,
                updatesViewport: false,
                showsCamera: true
            )
        } else {
            CameraPreviewView(
                session: viewModel.cameraManager.session,
                showsCamera: true,
                onTap: nil,
                onLongPress: nil,
                onDoubleTap: nil,
                onPinch: nil
            )
        }
    }

    @ViewBuilder
    private func previewSurface(in previewRect: CGRect) -> some View {
        if viewModel.cameraMode == .rearSpatial {
            SpatialCameraView(
                engine: viewModel.spatialEngine,
                previewZoom: viewModel.rearSpatialPreviewVisualZoom,
                showsCamera: false,
                onTap: offset(onFocusTap, by: previewRect.origin),
                onLongPress: offset(onSubjectPin, by: previewRect.origin),
                onDoubleTap: onClearPin,
                onPinch: zoomGesture
            )
        } else {
            CameraPreviewView(
                session: viewModel.cameraManager.session,
                showsCamera: false,
                onTap: offset(onFocusTap, by: previewRect.origin),
                onLongPress: offset(onSubjectPin, by: previewRect.origin),
                onDoubleTap: onClearPin,
                onPinch: zoomGesture
            )
        }
    }

    private var zoomGesture: ((CGFloat, Bool) -> Void)? {
        guard allowsZoomGestures else { return nil }
        return { magnification, isFinal in
            viewModel.updateZoom(magnification: magnification, isFinal: isFinal)
        }
    }

    private func offset(
        _ handler: ((CGPoint, CGPoint) -> Void)?,
        by origin: CGPoint
    ) -> ((CGPoint, CGPoint) -> Void)? {
        guard let handler else { return nil }
        return { localPoint, normalizedPoint in
            let screenPoint = CGPoint(
                x: localPoint.x + origin.x,
                y: localPoint.y + origin.y
            )
            handler(screenPoint, normalizedPoint)
        }
    }
}
