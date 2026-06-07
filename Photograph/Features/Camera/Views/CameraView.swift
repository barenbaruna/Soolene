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
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var viewModel = CameraViewModel()
    @State private var isShowingGallery = false
    @State private var tapIndicatorPoint: CGPoint? = nil
    @State private var showTapIndicator = false

    var body: some View {
        ZStack {
            // MARK: Layer 1 — Camera Preview

            CameraPreviewView(session: viewModel.cameraManager.session)
                .ignoresSafeArea()
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }
                // Single tap: pin subject at tapped position
                .onTapGesture { location in
                    handleSubjectTap(at: location)
                }
                // Double tap: clear pinned subject
                .onTapGesture(count: 2) {
                    viewModel.clearPinnedSubject()
                    showTapIndicator = false
                    tapIndicatorPoint = nil
                }

            // MARK: Layer 2 — Static Composition Grid (Core Graphics)

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

            // MARK: Layer 3 — Animated Dual-Anchor Guidance Overlay (SwiftUI)

            // Drawn in SwiftUI so it can use spring animations and Canvas.
            // Suppressed until the ML model produces its first prediction (hasMLData).
            // Shows: subject anchor, target socket, faint connector line.

            CompositionDirectionOverlay(
                composition: viewModel.resolvedComposition,
                subjectPoint: viewModel.analysis.bestSubjectPoint,
                targetPoint: viewModel.analysis.sceneGeometry.lockedTargetPoint,
                isPerfect: viewModel.analysis.isCompositionPerfect,
                hasSceneData: viewModel.analysis.hasSceneData,
                hasMLData: viewModel.analysis.hasMLData,
                alignmentScore: viewModel.analysis.sceneAlignmentScore,
                guidanceDistance: viewModel.analysis.guidanceDistance
            )
            .ignoresSafeArea()

            // MARK: Layer 4 — Tap Indicator

            // Appears briefly at the tapped point to confirm subject selection.
            if showTapIndicator, let pt = tapIndicatorPoint {
                TapSubjectIndicator()
                    .position(pt)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    .allowsHitTesting(false)
            }

            // MARK: Layer 5 — Removed (Moved to CameraControlsView)

            // MARK: Layer 6 — Camera Controls

            CameraControlsView(
                viewModel: viewModel,
                isShowingGallery: $isShowingGallery
            )

            // MARK: Layer 7 — Shutter Flash

            if viewModel.showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // MARK: Layer 8 — Walkthrough Overlay

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

    // MARK: - Tap Handling

    private func handleSubjectTap(at screenPoint: CGPoint) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return }

        let screenSize = window.bounds.size
        let normalisedPoint = CGPoint(
            x: screenPoint.x / screenSize.width,
            y: screenPoint.y / screenSize.height
        )
        viewModel.pinSubject(at: normalisedPoint)

        // Show brief visual indicator at tap location
        withAnimation(.easeOut(duration: 0.15)) {
            tapIndicatorPoint = screenPoint
            showTapIndicator = true
        }
        // Auto-hide the indicator after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) { showTapIndicator = false }
        }
    }
}

// MARK: - TapSubjectIndicator

/// Small pulsing crosshair shown at the user-tapped point to confirm subject selection.
private struct TapSubjectIndicator: View {
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AppColors.primary, lineWidth: 2)
                .frame(width: isExpanded ? 60 : 40, height: isExpanded ? 60 : 40)
                .opacity(isExpanded ? 0 : 1)

            Circle()
                .fill(AppColors.primary.opacity(0.3))
                .frame(width: 12, height: 12)

            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.primary)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { isExpanded = true }
        }
    }
}
