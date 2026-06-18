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
    @State private var walkthroughAnchors: [WalkthroughAnchorID: CGRect] = [:]
    @State private var permissionAlert: PermissionAlertKind?
    @State private var hasCompletedPermissionFlow = false
    @State private var hasLoadedInitialPermissions = false
    @SceneStorage("cameraPermissionFlowNeedsManualCompletion")
    private var permissionFlowNeedsManualCompletion = false

    var body: some View {
        Group {
            if viewModel.hasRequiredPermissions && hasCompletedPermissionFlow {
                cameraExperience
            } else {
                CameraPermissionGateView(
                    cameraStatus: viewModel.cameraPermission,
                    photoStatus: viewModel.photoReadPermission,
                    isRequestingCamera: viewModel.isRequestingCameraPermission,
                    isRequestingPhoto: viewModel.isRequestingPhotoPermission,
                    onRequestCameraAccess: { requestCameraAccess() },
                    onRequestPhotoAccess: { requestPhotoAccess() },
                    onComplete: { completePermissionFlow() }
                )
            }
        }
        .task {
            await viewModel.refreshPermissions()
            guard !hasLoadedInitialPermissions else { return }
            hasLoadedInitialPermissions = true
            if viewModel.hasRequiredPermissions && !permissionFlowNeedsManualCompletion {
                hasCompletedPermissionFlow = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await viewModel.refreshPermissions() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // UIDevice.current.orientation reflects physical orientation from the accelerometer,
            // independent of system Portrait Orientation Lock. This lets us match the native
            // camera behaviour: the app responds to real device rotation even when the system lock is on.
            viewModel.onDeviceOrientationChanged(UIDevice.current.orientation)
        }
        .alert(permissionAlertTitle, isPresented: Binding(
            get: { permissionAlert != nil },
            set: { if !$0 { permissionAlert = nil } }
        )) {
            Button("Open Settings") {
                permissionFlowNeedsManualCompletion = true
                viewModel.openAppSettings()
                permissionAlert = nil
            }
            Button("Not Now", role: .cancel) {
                permissionAlert = nil
            }
        } message: {
            Text(permissionAlertMessage)
        }
    }

    private var cameraExperience: some View {
        ZStack {
            CameraPreviewLayer(
                viewModel: viewModel,
                onFocusTap: onboarding.allowsCameraFocusControls ? handleFocusTap : nil,
                onSubjectPin: onboarding.allowsSceneLock ? handleSubjectPin : nil,
                onClearPin: onboarding.allowsCameraFocusControls ? clearPinnedSubject : nil,
                allowsZoomGestures: onboarding.allowsCameraFocusControls
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
                onResetExposure: { viewModel.resetExposure() },
                onDragExposure: { viewModel.showExposureTemporarily() }
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
                    message: handoffOverlayMessage,
                    aspectRatio: viewModel.selectedAspectRatio,
                    displayMultiplier: viewModel.zoomController.displayMultiplier
                )
            }

            WalkthroughOverlayView(
                context: .camera,
                anchors: walkthroughAnchors,
                hidesDuringCapture: viewModel.isCapturing
            )
        }
        .onPreferenceChange(WalkthroughAnchorPreferenceKey.self) { walkthroughAnchors = $0 }
        .onChange(of: viewModel.isCapturing) { wasCapturing, isCapturing in
            if wasCapturing, !isCapturing {
                onboarding.advanceAfterCapture()
            }
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
        .onChange(of: onboarding.currentStep) { _, step in
            guard step == .followGuide else { return }
            advanceGuideWalkthroughIfReady()
        }
        .fullScreenCover(isPresented: $isShowingGallery) {
            GalleryView(initialPhotoIdentifier: viewModel.lastSavedAssetIdentifier)
        }

        .onChange(of: viewModel.lastSavedAssetIdentifier) { _, identifier in
            guard let identifier else { return }
            onboarding.recordWalkthroughPhotoIdentifier(identifier)
        }
        .onChange(of: viewModel.trackingStabilityProgress) { _, _ in
            viewModel.syncHandoffRecovery()
        }
        .onChange(of: viewModel.captureReadiness) { wasReady, isReady in
            guard isReady.showsGreenCelebration, !wasReady.showsGreenCelebration else { return }
            advanceGuideWalkthroughIfReady()
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
        return "Capturing…"
    }

    private var permissionAlertTitle: String {
        switch permissionAlert {
        case .camera:
            return "Camera Access Needed"
        case .gallery:
            return "Gallery Access Needed"
        case nil:
            return ""
        }
    }

    private var permissionAlertMessage: String {
        switch permissionAlert {
        case .camera:
            return PrivacyPermissionService.cameraGateMessage(for: viewModel.cameraPermission)
        case .gallery:
            return PrivacyPermissionService.photoBrowseMessage(for: viewModel.photoReadPermission)
        case nil:
            return ""
        }
    }

    private func requestCameraAccess() {
        permissionFlowNeedsManualCompletion = true
        Task { @MainActor in
            await viewModel.requestCameraAccess()
            showSettingsAlertIfNeeded(for: .camera, status: viewModel.cameraPermission)
        }
    }

    private func requestPhotoAccess() {
        permissionFlowNeedsManualCompletion = true
        Task { @MainActor in
            await viewModel.requestPhotoReadAccess()
            showSettingsAlertIfNeeded(for: .gallery, status: viewModel.photoReadPermission)
        }
    }

    private func showSettingsAlertIfNeeded(for kind: PermissionAlertKind, status: PermissionStatus) {
        if status.needsSettings {
            permissionAlert = kind
        }
    }

    private func completePermissionFlow() {
        guard viewModel.hasRequiredPermissions else { return }
        permissionFlowNeedsManualCompletion = false
        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedPermissionFlow = true
        }
    }

    private func advanceGuideWalkthroughIfReady() {
        guard viewModel.captureReadiness.showsGreenCelebration else { return }
        onboarding.advanceAfterGuideCompletion()
    }

    // MARK: - Gestures

    private func handleFocusTap(at screenPoint: CGPoint, normalizedPoint: CGPoint) {
        viewModel.focusAndExpose(at: normalizedPoint)
        showFocusExposure(at: screenPoint)
    }

    private func handleSubjectPin(at screenPoint: CGPoint, normalizedPoint: CGPoint) {
        viewModel.pinSubject(at: normalizedPoint)
        onboarding.recordFirstSubjectLock()
        onboarding.advanceAfterSceneLock()
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

private enum PermissionAlertKind {
    case camera
    case gallery
}
