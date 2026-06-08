//
//  CameraBottomBar.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Bottom bar of the camera HUD, containing gallery link, shutter button, and camera switcher.
struct CameraBottomBar: View {
    let viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool
    let iconRotation: Double

    var body: some View {
        HStack(alignment: .center) {
            // Gallery thumbnail
            Button {
                HapticManager.selection()
                isShowingGallery = true
            } label: {
                Group {
                    if let thumb = viewModel.lastSavedThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: ControlMetrics.galleryThumbnail, height: ControlMetrics.galleryThumbnail)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                            )
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .glassCircle(size: ControlMetrics.iconButton)
                    }
                }
                .rotationEffect(.degrees(iconRotation))
            }
            .accessibilityLabel("Gallery")

            Spacer()

            // Capture / Stop
            if viewModel.isCountingDown {
                Button(action: { viewModel.cancelCountdown() }) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                            .frame(width: ControlMetrics.shutterOuter, height: ControlMetrics.shutterOuter)
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
            } else {
                CaptureButton { viewModel.capturePhoto() }
            }

            Spacer()

            // Flip camera
            Button { viewModel.switchCamera() } label: {
                ZStack {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.title3)
                        .opacity(viewModel.isSwitchingCamera ? 0 : 1)

                    if viewModel.isSwitchingCamera {
                        ProgressView()
                            .tint(AppColors.primary)
                    }
                }
                .foregroundStyle(AppColors.primary)
                .frame(width: ControlMetrics.iconButton, height: ControlMetrics.iconButton)
                .background(Color.black.opacity(0.41), in: Circle())
                .rotationEffect(.degrees(iconRotation))
            }
            .disabled(viewModel.isSwitchingCamera)
            .accessibilityLabel("Switch Camera")
        }
    }
}
