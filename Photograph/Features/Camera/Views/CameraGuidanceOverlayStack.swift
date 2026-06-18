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
            GeometryReader { proxy in
                let fullRect = proxy.frame(in: .local)
                let drawRect = aspectMaskedRect(in: fullRect, aspectRatio: viewModel.selectedAspectRatio)
                AspectMask(fullRect: fullRect, contentRect: drawRect)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.3), value: viewModel.selectedAspectRatio)

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

    /// Computes the aspect-ratio-masked drawing rect within the full preview frame.
    /// UI is portrait-locked, so the ratio is always portrait-proportioned.
    private func aspectMaskedRect(in rect: CGRect, aspectRatio: AspectRatioMode) -> CGRect {
        let ratio: CGFloat
        switch aspectRatio {
        case .oneOne: ratio = 1.0
        case .sixteenNine: ratio = 9.0 / 16.0
        case .fourThree: ratio = 3.0 / 4.0
        }

        var w = rect.width
        var h = w / ratio
        if h > rect.height { h = rect.height; w = h * ratio }

        return CGRect(
            x: rect.midX - w / 2,
            y: rect.midY - h / 2,
            width: w,
            height: h
        )
    }
}
