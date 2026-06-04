//
//  CameraView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import SwiftUI

/// Main camera screen.
struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var isShowingGallery = false

    var body: some View {
        ZStack {
            // MARK: Layer 1 — Camera Preview

            CameraPreviewView(session: viewModel.cameraManager.session)
                .ignoresSafeArea()
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }

            // MARK: Layer 2 — Composition Overlay

            CompositionOverlayView(
                composition: viewModel.resolvedComposition,
                geometry: viewModel.analysis.sceneGeometry,
                aspectRatio: viewModel.selectedAspectRatio,
                subjectOffset: viewModel.analysis.subjectOffset,
                isPerfect: viewModel.analysis.isCompositionPerfect,
                sceneAlignmentScore: viewModel.analysis.sceneAlignmentScore,
                hasSceneData: viewModel.analysis.hasSceneData
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // MARK: Layer 3 — Camera Controls

            CameraControlsView(
                viewModel: viewModel,
                isShowingGallery: $isShowingGallery
            )

            // MARK: Layer 4 — Shutter Flash

            if viewModel.showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        // Stop camera when gallery opens
        .onChange(of: isShowingGallery) { _, showing in
            if showing {
                viewModel.pauseSession()
            } else {
                viewModel.resumeSession()
            }
        }
        // Gallery
        .fullScreenCover(isPresented: $isShowingGallery) {
            GalleryView()
        }
        // Auto-save on capture
        .onChange(of: viewModel.cameraManager.capturedPhotoData) { _, newData in
            if newData != nil {
                Task { await viewModel.savePhoto() }
            }
        }
        .alert("Could Not Save", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
    }
}
