//
//  CameraSettingsSheet.swift
//  Photograph
//
//  iOS Camera-style settings grid presented as sheet.
//  3-column grid: Flash, Timer, EV (row 1), Aspect (row 2).
//
//  HIG §4.6: .buttonStyle(.glass) for interactive buttons
//  HIG §15.1: .regularMaterial for backgrounds
//  HIG §6.1: Spacing tokens for layout
//
//  Uses Design System: Typography, Spacing, AppColors.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import SwiftUI

struct CameraSettingsSheet: View {
    @Bindable var viewModel: CameraViewModel
    @State private var isExposureExpanded = false

    var body: some View {
        VStack(spacing: Spacing.medium) {
            if isExposureExpanded {
                ExposureControl(
                    value: Binding(
                        get: { viewModel.exposureBias },
                        set: { viewModel.setExposure($0) }
                    ),
                    onReset: { 
                        viewModel.resetExposure()
                        withAnimation { isExposureExpanded = false }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: Spacing.medium) {
                    settingItem(
                        icon: flashIcon,
                        label: "FLASH",
                        isActive: viewModel.isFlashActive,
                        action: { viewModel.cycleFlash() }
                    )

                    settingItem(
                        icon: "timer",
                        label: timerLabel,
                        isActive: viewModel.timerLength > 0,
                        action: { viewModel.cycleTimer() }
                    )

                    settingItem(
                        icon: "plus.forwardslash.minus",
                        label: exposureLabel,
                        isActive: viewModel.exposureBias != 0,
                        action: { 
                            withAnimation { isExposureExpanded = true } 
                        }
                    )

                    VStack(spacing: Spacing.small) {
                        AspectRatioButton(selectedRatio: $viewModel.selectedAspectRatio)
                            .frame(width: ControlMetrics.settingsSheetIcon, height: ControlMetrics.settingsSheetIcon)
                            .background(Color(.tertiarySystemFill), in: Circle())
                        Text("ASPECT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.medium)
        .presentationBackground(.regularMaterial)
    }

    // MARK: - Setting Item

    private func settingItem(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            VStack(spacing: Spacing.small) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isActive ? AppColors.primary : .white)
                    .frame(width: ControlMetrics.settingsSheetIcon, height: ControlMetrics.settingsSheetIcon)
                    .background(isActive ? AppColors.primary.opacity(0.15) : Color(.tertiarySystemFill), in: Circle())
                    .overlay(
                        Circle().strokeBorder(
                            isActive ? AppColors.primary.opacity(0.5) : .clear,
                            lineWidth: 1.5
                        )
                    )

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? AppColors.primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var flashIcon: String {
        if viewModel.isFrontCamera { return "bolt.slash.fill" }
        switch viewModel.flashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
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
