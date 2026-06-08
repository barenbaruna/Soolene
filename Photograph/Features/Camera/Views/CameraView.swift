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
    @State private var tapIndicatorStyle: TapIndicatorStyle = .focus
    @State private var showTapIndicator = false
    @State private var focusedPoint: CGPoint?
    @State private var isShowingFocusExposure = false

    var body: some View {
        ZStack {
            // MARK: Layer 1 — Camera Preview

            CameraPreviewView(
                session: viewModel.cameraManager.session,
                onTap: { viewPoint, devicePoint in
                    handleFocusTap(at: viewPoint, devicePoint: devicePoint)
                },
                onLongPress: { viewPoint, _ in
                    handleSubjectPin(at: viewPoint)
                },
                onDoubleTap: {
                    clearPinnedSubject()
                },
                onPinch: { magnification, isFinal in
                    viewModel.updateZoom(magnification: magnification, isFinal: isFinal)
                }
            )
                .ignoresSafeArea()
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }

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

    private func handleFocusTap(at screenPoint: CGPoint, devicePoint: CGPoint) {
        viewModel.focusAndExpose(at: devicePoint)
        showFocusExposure(at: screenPoint)
    }

    private func handleSubjectPin(at screenPoint: CGPoint) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return }

        let screenSize = window.bounds.size
        let normalisedPoint = CGPoint(
            x: screenPoint.x / screenSize.width,
            y: screenPoint.y / screenSize.height
        )
        viewModel.pinSubject(at: normalisedPoint)
        showIndicator(at: screenPoint, style: .pin)
    }

    private func clearPinnedSubject() {
        viewModel.clearPinnedSubject()
        showTapIndicator = false
        tapIndicatorPoint = nil
        isShowingFocusExposure = false
        focusedPoint = nil
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
                .strokeBorder(AppColors.primary, lineWidth: 1)
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
            .fill(AppColors.primary)
            .frame(width: Spacing.medium, height: 1)
    }
}

private struct ExposureRail: View {
    @Binding var value: Float
    let onReset: () -> Void

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
                    value = value(for: gesture.location.y)
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

    private func value(for locationY: CGFloat) -> Float {
        let clampedY = min(max(locationY, 0), ControlMetrics.exposureRailHeight)
        let normalized = 1 - (clampedY / ControlMetrics.exposureRailHeight)
        return Float((normalized * 4) - 2)
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
