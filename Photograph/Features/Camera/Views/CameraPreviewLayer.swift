//
//  CameraPreviewLayer.swift
//  Photograph
//

import SwiftUI

/// Rear spatial or front classic camera preview with gesture handlers.
struct CameraPreviewLayer: View {
    let viewModel: CameraViewModel
    let onFocusTap: (CGPoint, CGPoint) -> Void
    let onSubjectPin: (CGPoint, CGPoint) -> Void
    let onClearPin: () -> Void

    var body: some View {
        Group {
            if viewModel.cameraMode == .rearSpatial {
                SpatialCameraView(
                    engine: viewModel.spatialEngine,
                    previewZoom: viewModel.zoomController.displayMultiplier,
                    onTap: onFocusTap,
                    onLongPress: onSubjectPin,
                    onDoubleTap: onClearPin,
                    onPinch: { magnification, isFinal in
                        viewModel.updateZoom(magnification: magnification, isFinal: isFinal)
                    }
                )
            } else {
                CameraPreviewView(
                    session: viewModel.cameraManager.session,
                    onTap: onFocusTap,
                    onLongPress: onSubjectPin,
                    onDoubleTap: onClearPin,
                    onPinch: { magnification, isFinal in
                        viewModel.updateZoom(magnification: magnification, isFinal: isFinal)
                    }
                )
            }
        }
        .ignoresSafeArea()
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }
}
