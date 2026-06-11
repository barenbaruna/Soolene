//
//  CameraTopToolbar.swift
//  Photograph
//
//  Native-style top control row: Flash, Exposure, Timer, Aspect Ratio.
//  Active controls tint gold (#B6A71A) per design references.
//

import AVFoundation
import SwiftUI

struct CameraTopToolbar: View {
    let viewModel: CameraViewModel
    let iconRotation: Double
    let activePanel: CameraControlPanel?
    let onPanelTapped: (CameraControlPanel) -> Void

    var body: some View {
        HStack(spacing: Spacing.large) {
            toolbarButton(
                icon: flashIcon,
                isActive: viewModel.isFlashActive || activePanel == .flash,
                label: "Flash"
            ) {
                onPanelTapped(.flash)
            }

            toolbarButton(
                icon: "plus.forwardslash.minus",
                isActive: viewModel.exposureBias != 0 || activePanel == .exposure,
                label: "Exposure"
            ) {
                onPanelTapped(.exposure)
            }

            toolbarButton(
                icon: "timer",
                isActive: viewModel.timerLength > 0 || activePanel == .timer,
                label: "Timer"
            ) {
                onPanelTapped(.timer)
            }

            toolbarButton(
                icon: viewModel.selectedAspectRatio.symbolName,
                isActive: viewModel.selectedAspectRatio != .free || activePanel == .aspect,
                label: "Aspect ratio"
            ) {
                onPanelTapped(.aspect)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toolbarButton(
        icon: String,
        isActive: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isActive ? AppColors.controlActive : AppColors.textOnCamera)
                .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .rotationEffect(.degrees(iconRotation))
    }

    private var flashIcon: String {
        if viewModel.isFrontCamera { return "bolt.slash.fill" }
        switch viewModel.flashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
}

enum CameraControlPanel: Equatable {
    case flash
    case exposure
    case timer
    case aspect
}
