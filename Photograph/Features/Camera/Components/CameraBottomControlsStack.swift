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

    @Namespace private var glassNS

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
    /// Also handles Exposure scale when active, replacing Zoom with a morphing animation.
    @ViewBuilder
    private var compositionOrZoomSlot: some View {
        Group {
            if viewModel.activePanel == .exposure {
                ViewfinderExposureScale(
                    exposureBias: Binding(
                        get: { viewModel.exposureBias },
                        set: { viewModel.setExposure($0) }
                    ),
                    glassID: "ruler",
                    glassNamespace: glassNS,
                    onDragBegan: { viewModel.cancelExposureHideTimer() },
                    onDragEnded: { viewModel.showExposureTemporarily() }
                )
                .frame(height: ControlMetrics.rulerPanelContentHeight)
                .transition(.blurReplace)
            } else if !viewModel.isCountingDown, viewModel.guidancePhase.showPicker {
                CompositionPickerView(
                    selectedComposition: viewModel.userSelectedComposition,
                    mlSuggestion: viewModel.mlSuggestion,
                    compositions: viewModel.sortedPickerCompositions,
                    iconRotation: iconRotation,
                    onSelect: { viewModel.selectComposition($0) },
                    onClearSubject: { viewModel.clearPinnedSubject() }
                )
                .allowsHitTesting(onboarding.allowsCompositionControls)
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
                    isEnabled: !viewModel.isSwitchingCamera && onboarding.allowsCompositionControls,
                    glassID: "ruler",
                    glassNamespace: glassNS
                )
                .allowsHitTesting(onboarding.allowsCompositionControls)
                .frame(height: ControlMetrics.rulerPanelContentHeight)
                .transition(.blurReplace)
            } else {
                if CaptureArchitectureFlags.zoomRulerEnabled && viewModel.cameraMode == .rearSpatial {
                    ViewfinderZoomShortcuts(
                        viewModel: viewModel,
                        isEnabled: !viewModel.isSwitchingCamera && onboarding.allowsCompositionControls,
                        glassID: "ruler",
                        glassNamespace: glassNS,
                        iconRotation: iconRotation
                    )
                    .allowsHitTesting(onboarding.allowsCompositionControls)
                    .frame(height: ControlMetrics.rulerPanelContentHeight)
                    .transition(.blurReplace)
                } else {
                    Spacer()
                        .frame(height: ControlMetrics.rulerPanelContentHeight)
                }
            }
        }
        .padding(.bottom, Spacing.standard)
        .animation(.snappy, value: viewModel.activePanel)
        .animation(.snappy, value: viewModel.guidancePhase.isLocked)
        .animation(.snappy, value: viewModel.showsZoomRuler)
    }
}
