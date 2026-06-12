//
//  CameraView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import ARKit
import SwiftUI
import UIKit

/// Main camera screen.
struct CameraView: View {
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var viewModel = CameraViewModel()
    @State private var isShowingGallery = false
    @State private var tapIndicatorPoint: CGPoint? = nil
    @State private var tapIndicatorStyle: TapIndicatorStyle = .focus
    @State private var showTapIndicator = false
    @State private var focusedPoint: CGPoint?
    @State private var isShowingFocusExposure = false

    // Lock animation state
    @State private var lockRingPoint: CGPoint? = nil
    @State private var lockRingAnimating = false
    @State private var showLockIcon = false

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
            // MARK: Layer 1 — Camera Preview

            Group {
                if viewModel.cameraMode == .rearSpatial {
                    SpatialCameraView(
                        engine: viewModel.spatialEngine,
                        onTap: { viewPoint, normalizedPoint in
                            handleFocusTap(at: viewPoint, normalizedPoint: normalizedPoint)
                        },
                        onLongPress: { viewPoint, normalizedPoint in
                            handleSubjectPin(at: viewPoint, normalizedPoint: normalizedPoint)
                        },
                        onDoubleTap: {
                            clearPinnedSubject()
                        },
                        onPinch: { magnification, isFinal in
                            viewModel.updateZoom(magnification: magnification, isFinal: isFinal)
                        }
                    )
                } else {
                    CameraPreviewView(
                        session: viewModel.cameraManager.session,
                        onTap: { viewPoint, normalizedPoint in
                            handleFocusTap(at: viewPoint, normalizedPoint: normalizedPoint)
                        },
                        onLongPress: { viewPoint, normalizedPoint in
                            handleSubjectPin(at: viewPoint, normalizedPoint: normalizedPoint)
                        },
                        onDoubleTap: {
                            clearPinnedSubject()
                        },
                        onPinch: { magnification, isFinal in
                            viewModel.updateZoom(magnification: magnification, isFinal: isFinal)
                        }
                    )
                }
            }
                .ignoresSafeArea()
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }

            // MARK: Layer 2 — Static Composition Grid (Core Graphics)

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
            // Ghost grid during scanning (15% opacity), full during guidance
            .opacity(viewModel.guidancePhase.isActive ? 1.0 : 0.15)
            .animation(.easeInOut(duration: 0.5), value: viewModel.guidancePhase.isActive)

            // MARK: Layer 2.25 — Active guidance frame (design reference)

            if case .guiding = viewModel.guidancePhase, !viewModel.analysis.isCompositionPerfect {
                Rectangle()
                    .strokeBorder(AppColors.accent.opacity(0.85), lineWidth: 3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // MARK: Layer 2.5 — Scanning Phase Hints

            if !viewModel.guidancePhase.isActive {
                ScanningCoachOverlay(
                    saliencyCentroid: viewModel.analysis.sceneGeometry.saliencyCentroid,
                    faceDetected: !viewModel.analysis.sceneGeometry.faceRects.isEmpty
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: viewModel.guidancePhase.isActive)
            }

            // MARK: Layer 3 — Animated Dual-Anchor Guidance Overlay (SwiftUI)

            // Only shown when guidance phase is active (user has selected a composition).
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

            // MARK: Layer 3.5 — Lock Animation Ring

            if let lockPoint = lockRingPoint {
                LockAnimationRing(isAnimating: lockRingAnimating, showIcon: showLockIcon)
                    .position(lockPoint)
                    .allowsHitTesting(false)
            }

            // MARK: Layer 4 — Tap / Focus Indicator

            if showTapIndicator, let pt = tapIndicatorPoint {
                TapIndicator(style: tapIndicatorStyle)
                    .position(pt)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    .allowsHitTesting(false)
            }

            if isShowingFocusExposure, let focusedPoint {
                FocusExposureOverlay(
                    point: focusedPoint,
                    exposureBias: Binding(
                        get: { viewModel.exposureBias },
                        set: { viewModel.setExposure($0) }
                    ),
                    onReset: { viewModel.resetExposure() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
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
        .onChange(of: viewModel.shutterIsPerfect) { wasReady, isReady in
            guard isReady, !wasReady else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: "Composition ready. Capture now."
            )
        }
        .onChange(of: viewModel.spatialEngine.trackingState) { _, state in
            guard viewModel.cameraMode == .rearSpatial else { return }
            switch state {
            case .limited(let reason):
                viewModel.trackingQualityWarning = limitedTrackingMessage(reason)
            case .notAvailable:
                viewModel.trackingQualityWarning = "Move the device slowly to restore tracking."
            case .normal:
                if viewModel.trackingQualityWarning?.contains("approximate") != true
                    && viewModel.trackingQualityWarning?.contains("world lock") != true {
                    viewModel.trackingQualityWarning = nil
                }
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

    // MARK: - Tap Handling

    private func handleFocusTap(at screenPoint: CGPoint, normalizedPoint: CGPoint) {
        viewModel.focusAndExpose(at: normalizedPoint)
        showFocusExposure(at: screenPoint)
    }

    private func handleSubjectPin(at screenPoint: CGPoint, normalizedPoint: CGPoint) {
        viewModel.pinSubject(at: normalizedPoint)

        // Play lock animation at tap point
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

    /// Plays the lock-in ring burst animation at the pinned point.
    private func playLockAnimation(at point: CGPoint) {
        lockRingPoint = point
        lockRingAnimating = false
        showLockIcon = false

        // Ring burst
        withAnimation(.easeOut(duration: 0.35)) {
            lockRingAnimating = true
        }

        // Lock icon appear
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
            showLockIcon = true
        }

        // Fade out after a beat
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

    private func limitedTrackingMessage(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .excessiveMotion:
            return "Move the device more slowly."
        case .insufficientFeatures:
            return "Point at a textured surface for better tracking."
        case .initializing:
            return "Initializing spatial tracking…"
        case .relocalizing:
            return "Relocalizing — hold steady."
        @unknown default:
            return "Tracking is limited — hold steady."
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

// MARK: - Focus Exposure Overlay

private struct FocusExposureOverlay: View {
    let point: CGPoint
    @Binding var exposureBias: Float
    let onReset: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let clampedPoint = clampedFocusPoint(in: proxy.size)

            ZStack {
                FocusBox()
                    .position(clampedPoint)

                ExposureRail(
                    value: $exposureBias,
                    onReset: onReset
                )
                .position(
                    x: railX(focusPoint: clampedPoint, in: proxy.size),
                    y: clampedPoint.y
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
    }

    private func clampedFocusPoint(in size: CGSize) -> CGPoint {
        let margin = ControlMetrics.focusBox / 2 + Spacing.standard
        return CGPoint(
            x: min(max(point.x, margin), size.width - margin - ControlMetrics.exposureRailWidth),
            y: min(max(point.y, margin + Spacing.large), size.height - margin - ControlMetrics.cameraBottomBandHeight)
        )
    }

    private func railX(focusPoint: CGPoint, in size: CGSize) -> CGFloat {
        let preferred = focusPoint.x + ControlMetrics.focusBox / 2 + Spacing.medium
        if preferred + ControlMetrics.exposureRailWidth / 2 < size.width - Spacing.small {
            return preferred
        }
        return focusPoint.x - ControlMetrics.focusBox / 2 - Spacing.medium
    }
}

private struct FocusBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(AppColors.controlActive, lineWidth: 1)
                .frame(width: ControlMetrics.focusBox, height: ControlMetrics.focusBox)

            // Top and Bottom ticks
            VStack {
                tick
                Spacer()
                tick
            }
            .frame(width: ControlMetrics.focusBox, height: ControlMetrics.focusBox + Spacing.medium)

            // Left and Right ticks
            HStack {
                tick.rotationEffect(.degrees(90))
                Spacer()
                tick.rotationEffect(.degrees(90))
            }
            .frame(width: ControlMetrics.focusBox + Spacing.medium, height: ControlMetrics.focusBox)
        }
        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
    }

    private var tick: some View {
        Rectangle()
            .fill(AppColors.controlActive)
            .frame(width: Spacing.medium, height: 1)
    }
}

private struct ExposureRail: View {
    @Binding var value: Float
    let onReset: () -> Void
    @State private var dragStartValue: Float? = nil

    var body: some View {
        ZStack {
            // Thin vertical line
            Rectangle()
                .fill(AppColors.primary.opacity(0.8))
                .frame(width: 1, height: ControlMetrics.exposureRailHeight)
                
            // Sun icon slider
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(AppColors.primary)
                .background(Circle().fill(Color.black.opacity(0.2)).frame(width: 24, height: 24))
                .offset(y: knobOffset)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .frame(width: ControlMetrics.exposureRailWidth, height: ControlMetrics.exposureRailHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if dragStartValue == nil {
                        dragStartValue = value
                    }
                    if let start = dragStartValue {
                        // 100 points of drag = 1.0 exposure unit (less sensitive)
                        let delta = Float(-gesture.translation.height / 100.0)
                        value = min(max(start + delta, -2), 2)
                    }
                }
                .onEnded { _ in
                    dragStartValue = nil
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Exposure")
        .accessibilityValue(formattedValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 0.1, 2)
            case .decrement:
                value = max(value - 0.1, -2)
            @unknown default:
                break
            }
        }
    }

    private var knobOffset: CGFloat {
        let normalized = CGFloat((value + 2) / 4)
        return (0.5 - normalized) * ControlMetrics.exposureRailHeight
    }

    private var formattedValue: String {
        if abs(value) < 0.05 {
            return "0,0"
        }

        let number = Double(value).formatted(.number.precision(.fractionLength(1)))
        return number.replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Tap Indicator

private enum TapIndicatorStyle {
    case focus
    case pin

    var symbolName: String {
        switch self {
        case .focus: return "viewfinder"
        case .pin: return "plus"
        }
    }
}

/// Small pulsing crosshair shown at the user-tapped point to confirm focus or subject pinning.
private struct TapIndicator: View {
    let style: TapIndicatorStyle
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AppColors.primary, lineWidth: 2)
                .frame(
                    width: isExpanded ? ControlMetrics.focusIndicator : ControlMetrics.compactIconButton,
                    height: isExpanded ? ControlMetrics.focusIndicator : ControlMetrics.compactIconButton
                )
                .opacity(isExpanded ? 0 : 1)

            Circle()
                .fill(AppColors.primary.opacity(0.3))
                .frame(width: Spacing.standard, height: Spacing.standard)

            Image(systemName: style.symbolName)
                .font(.headline)
                .foregroundStyle(AppColors.primary)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { isExpanded = true }
        }
    }
}
