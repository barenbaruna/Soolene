//
//  CameraView.swift
//  Photograph
//

import SwiftUI
import UIKit

/// Main camera screen — orchestrates preview, guidance, controls, and side effects.
struct CameraView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @State private var viewModel = AppDependencies.shared.makeCameraViewModel()
    @State private var isShowingGallery = false
    @State private var tapIndicatorPoint: CGPoint?
    @State private var tapIndicatorStyle: TapIndicatorStyle = .focus
    @State private var showTapIndicator = false
    @State private var focusedPoint: CGPoint?
    @State private var isShowingFocusExposure = false
    @State private var lockRingPoint: CGPoint?
    @State private var lockRingAnimating = false
    @State private var showLockIcon = false
    @State private var previewSize: CGSize = .zero

    var body: some View {
        Group {
            if viewModel.hasCameraPermission {
                cameraExperience
            } else {
                CameraPermissionGateView(
                    status: viewModel.cameraPermission,
                    isRequesting: viewModel.isRequestingCameraPermission,
                    onRequestAccess: { Task { await viewModel.requestCameraAccess() } },
                    onOpenSettings: { viewModel.openAppSettings() }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await viewModel.refreshPermissions() }
        }
    }

    private var cameraExperience: some View {
        ZStack {
            CameraPreviewLayer(
                viewModel: viewModel,
                onFocusTap: handleFocusTap,
                onSubjectPin: handleSubjectPin,
                onClearPin: clearPinnedSubject
            )
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { previewSize = geo.size }
                        .onChange(of: geo.size) { _, size in previewSize = size }
                }
            }

            CameraGuidanceOverlayStack(viewModel: viewModel)

            CameraInteractionOverlays(
                lockRingPoint: lockRingPoint,
                lockRingAnimating: lockRingAnimating,
                showLockIcon: showLockIcon,
                showTapIndicator: showTapIndicator,
                tapIndicatorPoint: tapIndicatorPoint,
                tapIndicatorStyle: tapIndicatorStyle,
                isShowingFocusExposure: isShowingFocusExposure,
                focusedPoint: focusedPoint,
                exposureBias: Binding(
                    get: { viewModel.exposureBias },
                    set: { viewModel.setExposure($0) }
                ),
                onResetExposure: { viewModel.resetExposure() }
            )

            CameraControlsView(
                viewModel: viewModel,
                isShowingGallery: $isShowingGallery
            )

            if viewModel.showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if viewModel.isCaptureHandoffInProgress {
                CameraHandoffOverlay(
                    frozenPreview: viewModel.handoffFrozenPreviewImage,
                    message: handoffOverlayMessage
                )
            }

            WalkthroughOverlayView(context: .camera)
        }
        .onChange(of: isShowingGallery) { _, showing in
            if showing {
                viewModel.pauseSession()
            } else {
                viewModel.resumeSession()
            }
        }
        .onChange(of: onboarding.hasCompletedWalkthrough) { _, completed in
            if completed {
                isShowingGallery = false
            }
        }
        .fullScreenCover(isPresented: $isShowingGallery) {
            GalleryView()
        }
        .onChange(of: viewModel.spatialEngine.capturedPhotoData) { _, newData in
            if newData != nil {
                Task { await viewModel.savePhoto() }
            }
        }
        .onChange(of: viewModel.cameraManager.capturedPhotoData) { _, newData in
            if newData != nil {
                Task { await viewModel.savePhoto() }
            }
        }
        .onChange(of: viewModel.trackingStabilityProgress) { _, _ in
            viewModel.syncHandoffRecovery()
        }
        .onChange(of: viewModel.captureReadiness) { wasReady, isReady in
            guard isReady.showsGreenCelebration, !wasReady.showsGreenCelebration else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: "Composition ready. Capture now."
            )
        }
        .onChange(of: viewModel.analysis.bestSubjectPoint) { _, point in
            guard viewModel.isSubjectPinned, lockRingPoint != nil,
                  let point, previewSize.width > 0, previewSize.height > 0
            else { return }
            lockRingPoint = CoordinateMapper.viewPoint(from: point, in: previewSize)
        }
        .alert("Could Not Save", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
        .onChange(of: viewModel.captureError) { _, error in
            if let error {
                viewModel.showInlineToast(error)
                viewModel.clearCaptureError()
            }
        }
        .onChange(of: viewModel.saveError) { _, error in
            if let error {
                viewModel.showInlineToast(error)
            }
        }
    }

    private var handoffOverlayMessage: String {
        if viewModel.isHandoffRecovering {
            return "Realigning guidance…"
        }
        if viewModel.isMaxQualityCaptureEnabled {
            return "Capturing at maximum quality…"
        }
        return "Capturing…"
    }

    // MARK: - Gestures

    private func handleFocusTap(at screenPoint: CGPoint, normalizedPoint: CGPoint) {
        viewModel.focusAndExpose(at: normalizedPoint)
        showFocusExposure(at: screenPoint)
    }

    private func handleSubjectPin(at screenPoint: CGPoint, normalizedPoint: CGPoint) {
        viewModel.pinSubject(at: normalizedPoint)
        playLockAnimation(at: screenPoint)
        showIndicator(at: screenPoint, style: .pin)
    }

    private func clearPinnedSubject() {
        viewModel.clearPinnedSubject()
        showTapIndicator = false
        tapIndicatorPoint = nil
        isShowingFocusExposure = false
        focusedPoint = nil
        lockRingPoint = nil
    }

    private func playLockAnimation(at point: CGPoint) {
        lockRingPoint = point
        lockRingAnimating = false
        showLockIcon = false

        withAnimation(.easeOut(duration: 0.35)) {
            lockRingAnimating = true
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
            showLockIcon = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                lockRingPoint = nil
                showLockIcon = false
                lockRingAnimating = false
            }
        }
    }

    private func showFocusExposure(at screenPoint: CGPoint) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            focusedPoint = screenPoint
            isShowingFocusExposure = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.2)) {
                isShowingFocusExposure = false
            }
        }
    }

    private func showIndicator(at screenPoint: CGPoint, style: TapIndicatorStyle) {
        withAnimation(.easeOut(duration: 0.15)) {
            tapIndicatorPoint = screenPoint
            tapIndicatorStyle = style
            showTapIndicator = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) { showTapIndicator = false }
        }
    }
}
