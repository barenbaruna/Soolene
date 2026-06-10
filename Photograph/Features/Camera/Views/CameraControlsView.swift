//
//  CameraControlsView.swift
//  Photograph
//
//  Camera layout (portrait):
//  Organizes the decomposed components:
//  - CameraTopRow (Phase-aware guidance tip + settings sheet trigger)
//  - LensSelectorView + CompositionPickerView
//  - PinnedSubjectBadge (phase-aware status)
//  - CameraBottomBar (Gallery + Shutter + Flip)
//
//  The composition picker slides up when the user locks a subject,
//  replacing the static composition pill with an interactive selection strip.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

/// Full camera HUD template/container.
struct CameraControlsView: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var isShowingGallery: Bool

    @State private var isShowingSettingsSheet = false
    @State private var iconRotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Controls
            VStack(spacing: 0) {
                CameraTopRow(
                    viewModel: viewModel,
                    isCountingDown: viewModel.isCountingDown,
                    iconRotation: iconRotation,
                    onSettingsTapped: { isShowingSettingsSheet = true }
                )
                .padding(.top, Spacing.standard)
                .padding(.horizontal, Spacing.standard)
                .padding(.bottom, Spacing.medium)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            // Countdown Overlay
            if viewModel.isCountingDown {
                Text("\(viewModel.countdownValue)")
                    .font(.largeTitle.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, Spacing.large)
            }

            // MARK: - Bottom Controls
            VStack(spacing: 0) {
                if !viewModel.isCountingDown {
                    LensSelectorView(
                        availableLenses: LensType.availableOnDevice,
                        selectedLens: Binding(
                            get: { LensType(rawValue: viewModel.selectedLens) ?? .wide },
                            set: { viewModel.switchLens($0.rawValue) }
                        ),
                        iconRotation: iconRotation
                    )
                    .padding(.top, Spacing.medium)
                    .padding(.bottom, Spacing.small)

                    // Phase-driven composition area
                    if viewModel.guidancePhase.showPicker {
                        // Composition Picker — slides up with staggered pills
                        CompositionPickerView(
                            selectedComposition: viewModel.userSelectedComposition,
                            mlSuggestion: viewModel.mlSuggestion,
                            onSelect: { composition in
                                viewModel.selectComposition(composition)
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: viewModel.guidancePhase.showPicker)
                        .padding(.bottom, Spacing.small)

                        // Phase status badge
                        PinnedSubjectBadge(
                            phase: viewModel.guidancePhase,
                            composition: viewModel.userSelectedComposition
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.guidancePhase)
                    } else {
                        // Scanning state: show scanning hint badge
                        PinnedSubjectBadge(
                            phase: .scanning,
                            composition: nil
                        )
                        .transition(.opacity)
                        .padding(.bottom, Spacing.standard)
                    }
                }

                CameraBottomBar(
                    viewModel: viewModel,
                    isShowingGallery: $isShowingGallery,
                    iconRotation: iconRotation
                )
                .padding(.horizontal, Spacing.medium)
                .padding(.top, Spacing.standard)
                .padding(.bottom, Spacing.large)
            }
            .frame(maxWidth: .infinity)
        }
        // Settings Bottom Sheet
        .sheet(isPresented: $isShowingSettingsSheet) {
            CameraSettingsSheet(viewModel: viewModel)
                .presentationDetents([.height(ControlMetrics.settingsSheetHeight)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Spacing.cornerRadiusLarge)
        }

        // MARK: - Orientation Tracking

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
                case .landscapeLeft: iconRotation = 90
                case .landscapeRight: iconRotation = -90
                case .portraitUpsideDown: iconRotation = 180
                default: iconRotation = 0
                }
            }
        }
    }
}
