//
//  CameraView.swift
//  Photograph
//
//  Main camera screen. Layers (bottom to top):
//  1. Camera Preview (AVCaptureSession)
//  2. Composition Overlay (gridlines)
//  3. Camera Controls (HUD)
//  4. Shutter Flash
//  5. Walkthrough Overlay (onboarding tooltips)
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import SwiftUI

/// Main camera screen.
struct CameraView: View {
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var viewModel = CameraViewModel()
    @State private var isShowingGallery = false

    var body: some View {
        ZStack {
            // MARK: Layer 1 — Camera Preview

            CameraPreviewView(session: viewModel.cameraManager.session)
                .ignoresSafeArea()
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }

            // MARK: Layer 2 — Composition Overlay (live gridlines)

            CompositionOverlayView(
                composition: CompositionType(rawValue: viewModel.compositionLabel) ?? .center,
                isAligned: viewModel.isSceneAligned
            )
            .ignoresSafeArea()

            // MARK: Layer 3 — Camera Controls (HUD)

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

            // MARK: Layer 5 — Walkthrough Overlay

            WalkthroughOverlayView(context: .camera)
        }
        // Stop camera when gallery opens
        .onChange(of: isShowingGallery) { _, showing in
            if showing {
                viewModel.pauseSession()
            } else {
                viewModel.resumeSession()
            }
        }
        // Dismiss gallery automatically if they finish walkthrough while inside it
        .onChange(of: onboardingManager.hasCompletedWalkthrough) { _, completed in
            if completed {
                isShowingGallery = false
            }
        }
        // Gallery
        .fullScreenCover(isPresented: $isShowingGallery) {
            GalleryView()
        }
        // Auto-save on capture
        .onChange(of: viewModel.capturedPhotoData) { _, newData in
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
