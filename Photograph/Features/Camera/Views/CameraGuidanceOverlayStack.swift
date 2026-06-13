//
//  CameraGuidanceOverlayStack.swift
//  Photograph
//

import SwiftUI

/// Composition grids, scanning coach, and dual-anchor guidance above the preview.
struct CameraGuidanceOverlayStack: View {
    @Environment(OnboardingStore.self) private var onboarding
    let viewModel: CameraViewModel

    @State private var recordedScanCoachSession = false

    var body: some View {
        ZStack {
            if viewModel.guidancePhase.showsCompositionGrid,
               let composition = viewModel.guidancePhase.composition {
                CompositionOverlayView(
                    composition: composition,
                    geometry: viewModel.analysis.sceneGeometry,
                    aspectRatio: viewModel.selectedAspectRatio,
                    subjectOffset: viewModel.analysis.subjectOffset,
                    isPerfect: viewModel.captureReadiness.showsGreenCelebration,
                    isStabilizing: viewModel.captureReadiness.showsStabilizingUI,
                    sceneAlignmentScore: viewModel.analysis.sceneAlignmentScore,
                    hasSceneData: viewModel.analysis.hasSceneData,
                    showsIntersectionMarkers: !viewModel.showsDualAnchorGuidance
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: viewModel.guidancePhase.showsCompositionGrid)
            }

            if case .perfect = viewModel.guidancePhase, viewModel.captureReadiness.showsGreenCelebration {
                Rectangle()
                    .strokeBorder(AppColors.gridlineGreen.opacity(0.5), lineWidth: 2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if case .scanning = viewModel.guidancePhase {
                ScanningCoachOverlay(
                    saliencyCentroid: viewModel.analysis.sceneGeometry.saliencyCentroid,
                    faceDetected: !viewModel.analysis.sceneGeometry.faceRects.isEmpty,
                    showsViewfinderHint: onboarding.showsScanningViewfinderHint
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: viewModel.guidancePhase)
                .onAppear {
                    guard !recordedScanCoachSession else { return }
                    recordedScanCoachSession = true
                    onboarding.recordScanningCoachSession()
                }
            }

            if viewModel.showsDualAnchorGuidance,
               let composition = viewModel.guidancePhase.composition {
                CompositionDirectionOverlay(
                    composition: composition,
                    subjectPoint: viewModel.analysis.bestSubjectPoint,
                    targetPoint: viewModel.analysis.sceneGeometry.lockedTargetPoint,
                    isPerfect: viewModel.analysis.isCompositionPerfect,
                    showsGreenCelebration: viewModel.captureReadiness.showsGreenCelebration,
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
        .onChange(of: viewModel.guidancePhase) { _, phase in
            if case .scanning = phase { return }
            recordedScanCoachSession = false
        }
    }
}
