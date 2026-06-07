//
//  CameraSettingsSheet.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import SwiftUI

/// Bottom sheet with Flash, Timer, Exposure, Aspect controls.
/// Presented when the user taps the ellipsis button.
struct CameraSettingsSheet: View {
    @Bindable var viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle — provided by .presentationDragIndicator(.visible) automatically
            HStack(spacing: 0) {
                Spacer()

                // Flash
                settingButton(
                    icon: flashIcon,
                    label: "FLASH",
                    isActive: viewModel.isFlashActive
                ) { viewModel.cycleFlash() }

                Spacer()

                // Timer
                settingButton(
                    icon: "timer",
                    label: timerLabel,
                    isActive: viewModel.timerLength > 0
                ) { viewModel.cycleTimer() }

                Spacer()

                // Exposure
                settingButton(
                    icon: "plusminus",
                    label: exposureLabel,
                    isActive: viewModel.exposureBias != 0
                ) { viewModel.cycleExposure() }

                Spacer()

                // Aspect Ratio
                VStack(spacing: 6) {
                    AspectRatioButton(selectedRatio: $viewModel.selectedAspectRatio)
                        .frame(width: 56, height: 56)
                    Text("ASPECT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, Spacing.large)
        }
    }

    // MARK: - Setting Button

    private func settingButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isActive ? AppColors.primary : .primary)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(isActive ? AppColors.primary.opacity(0.2) : Color(.systemGray5))
                    )
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(isActive ? AppColors.primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Labels

    private var flashIcon: String {
        if viewModel.isFrontCamera { return "bolt.slash.fill" }
        return viewModel.isFlashActive ? "bolt.fill" : "bolt.slash.fill"
    }

    private var timerLabel: String {
        viewModel.timerLength > 0 ? "\(viewModel.timerLength)s" : "TIMER"
    }

    private var exposureLabel: String {
        let bias = viewModel.exposureBias
        if bias == 0 { return "EV" }
        return bias > 0 ? "+\(Int(bias))" : "\(Int(bias))"
    }
}
