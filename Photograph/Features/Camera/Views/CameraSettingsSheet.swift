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

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.medium) {
            // Flash
            settingItem(
                icon: flashIcon,
                label: "FLASH",
                isActive: viewModel.isFlashActive,
                action: { viewModel.cycleFlash() }
            )
            // Timer
            settingItem(
                icon: "timer",
                label: timerLabel,
                isActive: viewModel.timerLength > 0,
                action: { viewModel.cycleTimer() }
            )
            // Exposure
            settingItem(
                icon: "plusminus",
                label: exposureLabel,
                isActive: viewModel.exposureBias != 0,
                action: { viewModel.cycleExposure() }
            )
            // Aspect
            VStack(spacing: Spacing.small) {
                AspectRatioButton(selectedRatio: $viewModel.selectedAspectRatio)
                    .frame(width: 56, height: 56)
                    .background(Color(.tertiarySystemFill), in: Circle())
                Text("ASPECT")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.large)
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
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? AppColors.primary : .primary)
                    .frame(width: 56, height: 56)
                    .background(Color(.tertiarySystemFill), in: Circle())
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
