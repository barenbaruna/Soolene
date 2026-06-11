//
//  CameraBottomBar.swift
//  Photograph
//
//  Bottom camera band: gallery, shutter, flip (design reference).
//

import SwiftUI

struct CameraBottomBar: View {
    let viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool
    let iconRotation: Double

    var body: some View {
        HStack(alignment: .center) {
            Button {
                HapticManager.selection()
                isShowingGallery = true
            } label: {
                Group {
                    if let thumb = viewModel.lastSavedThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundStyle(AppColors.textOnCamera)
                    }
                }
                .frame(width: ControlMetrics.galleryThumbnail, height: ControlMetrics.galleryThumbnail)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .strokeBorder(AppColors.textOnCamera.opacity(0.35), lineWidth: 1)
                )
                .rotationEffect(.degrees(iconRotation))
            }
            .accessibilityLabel("Gallery")

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
            } else {
                CaptureButton(
                    action: { viewModel.capturePhoto() },
                    isPerfect: viewModel.shutterIsPerfect,
                    isDisabled: viewModel.isCapturing || !viewModel.isCaptureReady
                )
            }

            Spacer()

            Button { viewModel.switchCamera() } label: {
                ZStack {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .opacity(viewModel.isSwitchingCamera ? 0 : 1)

                    if viewModel.isSwitchingCamera {
                        ProgressView()
                            .tint(AppColors.textOnCamera)
                    }
                }
                .foregroundStyle(AppColors.textOnCamera)
                .frame(width: ControlMetrics.iconButton, height: ControlMetrics.iconButton)
                .rotationEffect(.degrees(iconRotation))
            }
            .disabled(viewModel.isSwitchingCamera)
            .accessibilityLabel("Switch Camera")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.standard)
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
    }
}
