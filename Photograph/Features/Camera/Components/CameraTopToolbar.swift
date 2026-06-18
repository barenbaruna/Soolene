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
        pillContent
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pillContent: some View {
        if #available(iOS 26, *) {
            toolbarStack
                .glassEffect(.regular.tint(Color.black.opacity(0.15)), in: .rect(cornerRadius: Spacing.cornerRadiusCapsule))
        } else {
            toolbarStack
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Spacing.cornerRadiusCapsule))
        }
    }

    private var toolbarStack: some View {
        HStack(spacing: Spacing.large) {
            toolbarButton(
                icon: flashIcon,
                isActive: viewModel.isFlashActive || activePanel == .flash,
                label: "Flash"
            ) {
                onPanelTapped(.flash)
            }

            toolbarButton(
                icon: "plusminus",
                isActive: activePanel == .exposure,
                label: "Exposure"
            ) {
                onPanelTapped(.exposure)
            }

            timerButton

            aspectRatioButton
        }
        .padding(.horizontal, Spacing.standard)
    }

    private var timerButton: some View {
        Button {
            HapticManager.selection()
            onPanelTapped(.timer)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "timer")
                    .font(.body.weight(.medium))
                    .foregroundStyle(viewModel.timerLength > 0 ? AppColors.controlActive : .primary)

                if viewModel.timerLength > 0 {
                    Text("\(viewModel.timerLength)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.controlActive)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timerAccessibilityLabel)
        .accessibilityAddTraits(viewModel.timerLength > 0 ? .isSelected : [])
        .rotationEffect(.degrees(iconRotation))
    }

    private var aspectRatioButton: some View {
        Button {
            HapticManager.selection()
            onPanelTapped(.aspect)
        } label: {
            ZStack {
                Text(viewModel.selectedAspectRatio.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    // We use a slight tracking to make the ratio look like a tailored symbol
                    .tracking(0.5)
            }
            .foregroundStyle(viewModel.selectedAspectRatio != .fourThree ? AppColors.controlActive : .primary)
            .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Aspect ratio: \(viewModel.selectedAspectRatio.rawValue)")
        .accessibilityAddTraits(viewModel.selectedAspectRatio != .fourThree ? .isSelected : [])
        .rotationEffect(.degrees(iconRotation))
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
                .foregroundStyle(isActive ? AppColors.controlActive : .primary)
                .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .rotationEffect(.degrees(iconRotation))
    }

    private var timerAccessibilityLabel: String {
        switch viewModel.timerLength {
        case 3: return "3 second timer"
        case 5: return "5 second timer"
        default: return "Timer off"
        }
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
