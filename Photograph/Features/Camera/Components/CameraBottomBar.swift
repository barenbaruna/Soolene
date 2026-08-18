//
//  CameraBottomBar.swift
//  Soolene
//
//  Bottom camera band: gallery, shutter, flip (design reference).
//

import SwiftUI

struct CameraBottomBar: View {
    @Environment(OnboardingStore.self) private var onboarding
    let viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool
    let iconRotation: Double

    var body: some View {
        HStack(alignment: .center) {
            Button(action: openGallery) {
                Group {
                    if let thumb = viewModel.lastSavedThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .rotationEffect(.degrees(iconRotation)) // Rotate the thumbnail internally
                    } else {
                        Image(AppIcon.iconGallery)
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .rotationEffect(.degrees(iconRotation)) // Rotate the icon internally
                    }
                }
                .frame(width: ControlMetrics.galleryThumbnail, height: ControlMetrics.galleryThumbnail)
                .contentShape(Circle())
                .clipShape(Circle())
                .background(glassButtonBackground)
            }
            .accessibilityLabel("Gallery")
            .walkthroughAnchor(.gallery)
            .disabled(!onboarding.allowsGalleryButton)

            Spacer()

            if viewModel.isCountingDown {
                Button(action: { viewModel.cancelCountdown() }) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: ControlMetrics.shutterOuter, height: ControlMetrics.shutterOuter)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                    }
                }
                .accessibilityLabel("Stop timer")
                .disabled(!onboarding.allowsShutter)
            } else {
                CaptureButton(
                    action: capturePhoto,
                    readiness: viewModel.shutterReadiness,
                    isDisabled: viewModel.isCapturing
                        || !viewModel.isCaptureReady
                        || !onboarding.allowsShutter
                )
                .walkthroughAnchor(.shutter)
            }

            Spacer()

            Button { viewModel.switchCamera() } label: {
                ZStack {
                    Image(systemName: AppIcon.iconFlipCamera)
                        .font(.title2)
                        .opacity(viewModel.isSwitchingCamera ? 0 : 1)
                        .rotationEffect(.degrees(iconRotation)) // Rotate the icon internally

                    if viewModel.isSwitchingCamera {
                        ProgressView()
                            .tint(.primary)
                    }
                }
                .foregroundStyle(.primary)
                .frame(width: ControlMetrics.iconButton, height: ControlMetrics.iconButton)
                .contentShape(Circle())
                .background(glassButtonBackground)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSwitchingCamera || !onboarding.allowsCameraSwitch)
            .accessibilityLabel("Switch Camera")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.standard)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var glassButtonBackground: some View {
        if #available(iOS 26, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.15)), in: .circle)
                // Explicit white border: stroke lives in the background layer where
                // .colorScheme(.light) is active, so Color.primary would resolve to dark.
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
        }
    }

    private func openGallery() {
        guard onboarding.allowsGalleryButton else { return }
        HapticManager.selection()
        onboarding.advanceAfterOpeningGallery()
        isShowingGallery = true
    }

    private func capturePhoto() {
        guard onboarding.allowsShutter else { return }
        viewModel.capturePhoto()
    }
}
