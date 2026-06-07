//
//  CameraControlsView.swift
//  Photograph
//
//  Camera layout (portrait):
//  Organizes the decomposed components:
//  - CameraTopRow (Guidance tip + settings sheet trigger)
//  - LensSelectorView + Composition Pill
//  - CameraBottomBar (Gallery + Shutter + Flip)
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
            // Top Row: Guidance Tip + Settings
            CameraTopRow(
                viewModel: viewModel,
                isCountingDown: viewModel.isCountingDown,
                iconRotation: iconRotation,
                onSettingsTapped: { isShowingSettingsSheet = true }
            )
            .padding(.top, Spacing.standard)
            .padding(.horizontal, Spacing.standard)



            Spacer()

            // Countdown Overlay
            if viewModel.isCountingDown {
                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, Spacing.large)
            }

            // Lens Selector
            if !viewModel.isFrontCamera,
               !viewModel.isCountingDown
            {
                LensSelectorView(
                    availableLenses: [LensType.ultraWide, LensType.wide, LensType.twoX],
                    selectedLens: Binding(
                        get: { LensType(rawValue: viewModel.selectedLens) ?? .wide },
                        set: { viewModel.switchLens($0.rawValue) }
                    )
                )
                .padding(.bottom, Spacing.small)
            }

            // Composition Pill
            if !viewModel.isCountingDown {
                compositionPill
            }

            // Bottom Bar: Gallery / Shutter / Flip
            CameraBottomBar(
                viewModel: viewModel,
                isShowingGallery: $isShowingGallery,
                iconRotation: iconRotation
            )
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.medium)
        }
        // Settings Bottom Sheet
        .sheet(isPresented: $isShowingSettingsSheet) {
            CameraSettingsSheet(viewModel: viewModel)
                .presentationDetents([.height(220)])
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

    // MARK: - Components

    private var compositionPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.viewfinder")
                .font(.caption)
            Text(viewModel.compositionLabel)
                .textStyle(Typography.subheadline)
        }
        .foregroundStyle(.white)
        .glassPill()
        .animation(.easeInOut(duration: 0.3), value: viewModel.compositionLabel)
        .padding(.bottom, Spacing.standard)
    }
}
