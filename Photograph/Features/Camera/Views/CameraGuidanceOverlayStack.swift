//
//  CameraGuidanceOverlayStack.swift
//  Photograph
//

import SwiftUI

/// Composition grids, scanning coach, and dual-anchor guidance above the preview.
struct CameraGuidanceOverlayStack: View {
    let viewModel: CameraViewModel

    var body: some View {
        ZStack {
            CompositionOverlayView(
                composition: viewModel.resolvedComposition,
                geometry: viewModel.analysis.sceneGeometry,
                aspectRatio: viewModel.selectedAspectRatio,
                subjectOffset: viewModel.analysis.subjectOffset,
                isPerfect: viewModel.shutterIsPerfect,
                isStabilizing: viewModel.isStabilizingForCapture,
                sceneAlignmentScore: viewModel.analysis.sceneAlignmentScore,
                hasSceneData: viewModel.analysis.hasSceneData
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(viewModel.guidancePhase.isActive ? 1.0 : 0.15)
            .animation(.easeInOut(duration: 0.5), value: viewModel.guidancePhase.isActive)

            if case .guiding = viewModel.guidancePhase, !viewModel.analysis.isCompositionPerfect {
                Rectangle()
                    .strokeBorder(AppColors.accent.opacity(0.85), lineWidth: 3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if !viewModel.guidancePhase.isActive {
                ScanningCoachOverlay(
                    saliencyCentroid: viewModel.analysis.sceneGeometry.saliencyCentroid,
                    faceDetected: !viewModel.analysis.sceneGeometry.faceRects.isEmpty
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: viewModel.guidancePhase.isActive)
            }

            if viewModel.showsDualAnchorGuidance {
                CompositionDirectionOverlay(
                    composition: viewModel.resolvedComposition,
                    subjectPoint: viewModel.analysis.bestSubjectPoint,
                    targetPoint: viewModel.analysis.sceneGeometry.lockedTargetPoint,
                    isPerfect: viewModel.analysis.isCompositionPerfect,
                    isCaptureReady: viewModel.isCaptureReady,
                    hasSceneData: viewModel.analysis.hasSceneData,
                    hasMLData: viewModel.analysis.hasMLData,
                    alignmentScore: viewModel.analysis.sceneAlignmentScore,
                    guidanceDistance: viewModel.analysis.guidanceDistance
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.guidancePhase.isActive)
            }
        }
    }
}
