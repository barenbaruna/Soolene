//
//  CameraControlsView.swift
//  Photograph
//
//  Camera HUD layout (portrait):
//
//  ┌──────────────────────────────────┐
//  │  [Guidance Tip]          [⋯ btn] │  ← top row
//  │                                  │
//  │        [Countdown / empty]        │  ← middle spacer
//  │                                  │
//  │       [0.5×] [1×] [2×] [5×]      │  ← lens selector
//  │  ⊞ Rule of Thirds (pill)         │  ← composition label
//  │  [Gallery] [●  Shutter] [↺ Flip] │  ← bottom bar
//  └──────────────────────────────────┘
//
//  Tapping ⋯ opens a bottom sheet with Flash / Timer / Exposure / Aspect.
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import AVFoundation
import SwiftUI

/// Full camera HUD. Guidance tip + settings sheet trigger in the top row,
/// then lens selector + composition pill, then shutter bottom bar.
struct CameraControlsView: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool

    @State private var isShowingSettingsSheet = false
    @State private var iconRotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {

            // ── Top Row: Guidance Tip (left-centre) + Settings button (right) ──
            topRow
                .padding(.top, Spacing.standard)
                .padding(.horizontal, Spacing.standard)

            Spacer()

            // ── Countdown Overlay ──────────────────────────────────────────────
            if viewModel.isCountingDown {
                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, Spacing.large)
            }

            // ── Lens Selector ──────────────────────────────────────────────────
            if !viewModel.cameraManager.isUsingFrontCamera,
               viewModel.cameraManager.availableLenses.count > 1,
               !viewModel.isCountingDown
            {
                LensSelectorView(
                    availableLenses: viewModel.cameraManager.availableLenses,
                    selectedLens: Binding(
                        get: { viewModel.cameraManager.selectedLens },
                        set: { viewModel.switchLens($0) }
                    )
                )
                .padding(.bottom, Spacing.small)
            }

            // ── Composition Pill ───────────────────────────────────────────────
            if !viewModel.isCountingDown {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.resolvedComposition.symbolName)
                        .font(.caption)
                    Text(viewModel.compositionLabel)
                        .textStyle(Typography.subheadline)
                }
                .foregroundStyle(.white)
                .glassPill()
                .animation(.easeInOut(duration: 0.3), value: viewModel.compositionLabel)
                .padding(.bottom, Spacing.standard)
            }

            // ── Bottom Bar: Gallery / Shutter / Flip ───────────────────────────
            bottomBar
                .padding(.bottom, Spacing.medium)
        }
        // ── Settings Bottom Sheet ──────────────────────────────────────────────
        .sheet(isPresented: $isShowingSettingsSheet) {
            CameraSettingsSheet(viewModel: viewModel)
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Spacing.cornerRadiusLarge)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            let o = UIDevice.current.orientation
            withAnimation(.spring(response: 0.3)) {
                switch o {
                case .landscapeLeft:      iconRotation = 90
                case .landscapeRight:     iconRotation = -90
                case .portraitUpsideDown: iconRotation = 180
                default:                  iconRotation = 0
                }
            }
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        VStack(spacing: Spacing.small) {
            // Settings button — top-right
            HStack {
                Spacer()
                if !viewModel.isCountingDown {
                    Button {
                        HapticManager.selection()
                        isShowingSettingsSheet = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(iconRotation))
                            .glassCircle(size: 40)
                    }
                    .accessibilityLabel("Camera Settings")
                }
            }

            // Guidance tip — centered, below the settings button
            if let technique = viewModel.activeTechnique, !viewModel.isCountingDown {
                GuidanceTipView(tip: technique.tip)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
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
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                            )
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .glassCircle()
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
                            .frame(width: 76, height: 76)
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
                Image(systemName: "camera.rotate.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .glassCircle()
                    .rotationEffect(.degrees(iconRotation))
            }
            .accessibilityLabel("Switch Camera")
        }
        .padding(.horizontal, Spacing.large)
    }
}

// MARK: - Camera Settings Sheet

/// Bottom sheet with Flash, Timer, Exposure, Aspect controls.
/// Presented when the user taps the ⋯ button.
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
                    isActive: viewModel.cameraManager.flashMode != .off
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
                    isActive: viewModel.cameraManager.exposureBias != 0
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

    @ViewBuilder
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
                    .foregroundStyle(isActive ? .yellow : .primary)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(isActive ? Color.yellow.opacity(0.15) : Color(.systemGray5))
                    )
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? .yellow : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Labels

    private var flashIcon: String {
        if viewModel.cameraManager.isUsingFrontCamera { return "bolt.slash.fill" }
        switch viewModel.cameraManager.flashMode {
        case .on:   return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .off:  return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    private var timerLabel: String {
        viewModel.timerLength > 0 ? "\(viewModel.timerLength)s" : "TIMER"
    }

    private var exposureLabel: String {
        let bias = viewModel.cameraManager.exposureBias
        if bias == 0 { return "EV" }
        return bias > 0 ? "+\(Int(bias))" : "\(Int(bias))"
    }
}
