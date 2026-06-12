//
//  CameraBottomControlsStack.swift
//  Photograph
//
//  Zoom chips, composition picker, and shutter band above the home indicator.
//

import SwiftUI

struct CameraBottomControlsStack: View {
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

            if !viewModel.isCountingDown {
                LensSelectorView(
                    availableLenses: viewModel.availableLenses,
                    selectedLens: LensType(rawValue: viewModel.selectedLens) ?? .wide,
                    onSelect: { viewModel.switchLens($0) },
                    iconRotation: iconRotation,
                    isEnabled: !viewModel.isSwitchingCamera
                )
                .opacity(viewModel.isSwitchingCamera ? 0.5 : 1)
                .padding(.bottom, Spacing.tiny)

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
}
