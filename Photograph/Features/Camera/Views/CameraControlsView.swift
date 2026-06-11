//
//  CameraControlsView.swift
//  Photograph
//
//  Camera HUD: top toolbar, guidance, zoom ruler, composition picker, bottom band.
//

import SwiftUI

struct CameraControlsView: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool

    @State private var iconRotation: Double = 0
    @State private var activePanel: CameraControlPanel?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.small) {
                CameraTopToolbar(
                    viewModel: viewModel,
                    iconRotation: iconRotation,
                    activePanel: activePanel,
                    onPanelTapped: handlePanelTap
                )
                .padding(.top, Spacing.small)

                CameraTopRow(
                    viewModel: viewModel,
                    isCountingDown: viewModel.isCountingDown
                )
            }
            .padding(.horizontal, Spacing.standard)

            Spacer()

            if viewModel.isCountingDown {
                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.primary)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            }

            if activePanel == .exposure {
                ViewfinderExposureScale(
                    exposureBias: Binding(
                        get: { viewModel.exposureBias },
                        set: { viewModel.setExposure($0) }
                    ),
                    onDismiss: { withAnimation { activePanel = nil } }
                )
                .padding(.bottom, Spacing.standard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack(spacing: Spacing.small) {
                if !viewModel.isCountingDown {
                    ZoomRulerView(
                        lenses: viewModel.availableLenses,
                        selectedLens: LensType(rawValue: viewModel.selectedLens) ?? .wide,
                        onSelect: { viewModel.switchLens($0) }
                    )
                    .disabled(viewModel.isSwitchingCamera)
                    .opacity(viewModel.isSwitchingCamera ? 0.5 : 1)
                    .padding(.bottom, Spacing.small)

                    if viewModel.guidancePhase.showPicker {
                        CompositionPickerView(
                            selectedComposition: viewModel.userSelectedComposition,
                            mlSuggestion: viewModel.mlSuggestion,
                            compositions: viewModel.sortedPickerCompositions,
                            onSelect: { viewModel.selectComposition($0) }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        if case .subjectLocked = viewModel.guidancePhase {
                            Text("Double-tap to unlock subject")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textGuide)
                        }
                    }
                }

                CameraBottomBar(
                    viewModel: viewModel,
                    isShowingGallery: $isShowingGallery,
                    iconRotation: iconRotation
                )
            }
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
            let o = UIDevice.current.orientation
            withAnimation(.spring(response: 0.3)) {
                switch o {
                case .landscapeLeft: iconRotation = 90
                case .landscapeRight: iconRotation = -90
                case .portraitUpsideDown: iconRotation = 180
                default: iconRotation = 0
                }
            }
        }
    }

    private func handlePanelTap(_ panel: CameraControlPanel) {
        switch panel {
        case .flash:
            activePanel = nil
            viewModel.cycleFlash()
        case .timer:
            withAnimation { activePanel = activePanel == .timer ? nil : .timer }
            viewModel.cycleTimer()
        case .aspect:
            withAnimation { activePanel = activePanel == .aspect ? nil : .aspect }
            cycleAspectRatio()
        case .exposure:
            withAnimation {
                activePanel = activePanel == .exposure ? nil : .exposure
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
