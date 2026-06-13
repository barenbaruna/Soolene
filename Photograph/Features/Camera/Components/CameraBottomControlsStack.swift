//
//  CameraBottomControlsStack.swift
//  Photograph
//
//  Zoom ruler (viewfinder), composition picker, and shutter band.
//

import SwiftUI

struct CameraBottomControlsStack: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Bindable var viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool
    let iconRotation: Double

    var body: some View {
        VStack(spacing: Spacing.small) {
            if let toast = viewModel.inlineToastMessage {
                CaptureErrorToast(message: toast)
                    .padding(.horizontal, Spacing.standard)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.showsTrackingStabilityMeter {
                TrackingStabilityMeter(progress: viewModel.trackingStabilityProgress)
                    .padding(.bottom, Spacing.tiny)
                    .transition(.opacity)
            }

            compositionOrZoomSlot

            CameraBottomBar(
                viewModel: viewModel,
                isShowingGallery: $isShowingGallery,
                iconRotation: iconRotation
            )
        }
    }

    /// Composition picker and zoom ruler share one HUD slot above the shutter bar.
    @ViewBuilder
    private var compositionOrZoomSlot: some View {
        Group {
            if !viewModel.isCountingDown, viewModel.guidancePhase.showPicker {
                CompositionPickerView(
                    selectedComposition: viewModel.userSelectedComposition,
                    mlSuggestion: viewModel.mlSuggestion,
                    compositions: viewModel.sortedPickerCompositions,
                    onSelect: { viewModel.selectComposition($0) },
                    onClearSubject: { viewModel.clearPinnedSubject() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    SubjectUnlockTipController.updateShouldShow(
                        hasCompletedWalkthrough: onboarding.hasCompletedWalkthrough,
                        hasLockedSubjectOnce: onboarding.hasLockedSubjectOnce,
                        showsPicker: true
                    )
                }
                .onDisappear {
                    SubjectUnlockTipController.updateShouldShow(
                        hasCompletedWalkthrough: onboarding.hasCompletedWalkthrough,
                        hasLockedSubjectOnce: onboarding.hasLockedSubjectOnce,
                        showsPicker: false
                    )
                }
            } else if viewModel.showsZoomRuler {
                ViewfinderZoomRuler(
                    viewModel: viewModel,
                    isEnabled: !viewModel.isSwitchingCamera
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: ControlMetrics.rulerPanelContentHeight)
        .padding(.bottom, Spacing.tiny)
        .animation(.snappy, value: viewModel.guidancePhase.isLocked)
        .animation(.snappy, value: viewModel.showsZoomRuler)
    }
}
