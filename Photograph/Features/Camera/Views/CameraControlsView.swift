//
//  CameraControlsView.swift
//  Photograph
//
//  Camera HUD: top toolbar, guidance, exposure overlay, bottom controls.
//

import SwiftUI

struct CameraControlsView: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool

    @State private var iconRotation: Double = 0

    var body: some View {
        ZStack {
            if viewModel.activePanel == .exposure {
                RulerPanelDismissScrim {
                    withAnimation(.snappy) { viewModel.activePanel = nil }
                }
            }

            mainControls
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            updateIconRotation(for: UIDevice.current.orientation)
        }
        .sensoryFeedback(.success, trigger: viewModel.captureReadiness) { old, new in
            new.showsGreenCelebration && !old.showsGreenCelebration
        }
    }

    private var mainControls: some View {
        VStack(spacing: 0) {
            topSection
            Spacer()

            if viewModel.isCountingDown {
                CameraCountdownOverlay(value: viewModel.countdownValue)
            }

            CameraBottomControlsStack(
                viewModel: viewModel,
                isShowingGallery: $isShowingGallery,
                iconRotation: iconRotation
            )
        }
    }

    private var topSection: some View {
        VStack(spacing: Spacing.massive) {
            CameraTopToolbar(
                viewModel: viewModel,
                iconRotation: iconRotation,
                activePanel: viewModel.activePanel,
                onPanelTapped: handlePanelTap
            )
            .padding(.top, Spacing.small)

            CameraTopRow(
                viewModel: viewModel,
                isCountingDown: viewModel.isCountingDown
            )
        }
        .padding(.horizontal, Spacing.standard)
    }

    private func updateIconRotation(for orientation: UIDeviceOrientation) {
        withAnimation(.spring(response: 0.3)) {
            switch orientation {
            case .landscapeLeft: iconRotation = 90
            case .landscapeRight: iconRotation = -90
            case .portraitUpsideDown: iconRotation = 180
            default: iconRotation = 0
            }
        }
    }

    private func handlePanelTap(_ panel: CameraControlPanel) {
        switch panel {
        case .flash:
            viewModel.activePanel = nil
            viewModel.cycleFlash()
        case .timer:
            viewModel.cycleTimer()
        case .aspect:
            withAnimation { viewModel.activePanel = viewModel.activePanel == .aspect ? nil : .aspect }
            cycleAspectRatio()
        case .exposure:
            withAnimation(.snappy) {
                if viewModel.activePanel == .exposure {
                    viewModel.activePanel = nil
                } else {
                    viewModel.showExposureTemporarily()
                }
            }
        }
    }

    private func cycleAspectRatio() {
        let all = AspectRatioMode.allCases
        guard let idx = all.firstIndex(of: viewModel.selectedAspectRatio) else { return }
        let next = all.index(after: idx)
        viewModel.selectedAspectRatio = next < all.endIndex ? all[next] : all[all.startIndex]
        HapticManager.selection()
    }
}
