//
//  WalkthroughOverlayView.swift
//  Photograph
//
//  Renders walkthrough tooltips precisely on the camera & detail views.
//
//  Tooltip positions (1:1 with Hi-Fi mockups):
//  ┌─────────────────────────────────┐
//  │ Step 1: Hold and lock scene     │  → Centered because the user picks the scene
//  │ Step 2: Follow the Guide        │  → Below guidance tip pill, center
//  │ Step 3: Ready to Shoot          │  → Just above capture button, center
//  │ Step 4: View Your Shots         │  → Above gallery thumbnail, bottom-left
//  │ Step 5: Grid Guide              │  → Below grid toggle, top-right (detail)
//  │ Step 6: Hide Grid               │  → Same position (detail)
//  │ Step 7: Congratulation          │  → Centered card (detail)
//  └─────────────────────────────────┘
//
//  Uses Design System: Spacing, AppColors.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

// MARK: - Context

/// Determines which steps render on which screen.
enum WalkthroughContext {
    case camera   // Steps 1–4
    case detail   // Steps 5–7
}

// MARK: - WalkthroughOverlayView

struct WalkthroughOverlayView: View {
    @Environment(OnboardingStore.self) private var store
    let context: WalkthroughContext
    var anchors: [WalkthroughAnchorID: CGRect] = [:]
    var hidesDuringCapture: Bool = false

    var body: some View {
        if store.isWalkthroughActive, !shouldHideForCapture {
            GeometryReader { geo in
                ZStack {
                    tooltipForCurrentStep(in: geo)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .transition(.opacity)
        }
    }

    private var shouldHideForCapture: Bool {
        hidesDuringCapture && context == .camera && store.currentStep == .readyToShoot
    }

    // MARK: - Step Router

    @ViewBuilder
    private func tooltipForCurrentStep(in geo: GeometryProxy) -> some View {
        let screenW = geo.size.width
        let screenH = geo.size.height
        let containerFrame = geo.frame(in: .global)

        switch store.currentStep {

        case .compositionSuggestion where context == .camera:
            TooltipView(
                title: "Hold and lock scene",
                description: "Long-press scene you want to capture",
                primaryLabel: nil,
                anchor: .none
            )
            .frame(width: min(screenW * 0.82, 340))
            .position(
                x: screenW * 0.50,
                y: screenH * 0.36
            )

        case .followGuide where context == .camera:
            TooltipView(
                title: "Follow the Guide",
                description: "Follow the on-screen directions and adjust your framing",
                primaryLabel: nil,
                anchor: .top
            )
            .frame(width: min(screenW * 0.82, 340))
            .position(
                tooltipPosition(
                    for: .guidanceTip,
                    style: .top,
                    screenW: screenW,
                    screenH: screenH,
                    safeAreaTop: geo.safeAreaInsets.top,
                    containerFrame: containerFrame
                )
            )

        case .readyToShoot where context == .camera:
            TooltipView(
                title: "Ready to Shoot",
                description: "Tap this button to capture your photo once you've lined up the perfect composition guidelines.",
                primaryLabel: nil,
                anchor: .bottom
            )
            .frame(width: min(screenW * 0.80, 320))
            .position(
                tooltipPosition(
                    for: .shutter,
                    style: .bottom,
                    screenW: screenW,
                    screenH: screenH,
                    safeAreaTop: geo.safeAreaInsets.top,
                    containerFrame: containerFrame
                )
            )

        case .viewShots where context == .camera:
            TooltipView(
                title: "View Your Shots",
                description: "Tap here to view and review all the photos you have captured using the composition guides.",
                primaryLabel: nil,
                anchor: .bottomLeading
            )
            .frame(width: min(screenW * 0.82, 340))
            .position(
                tooltipPosition(
                    for: .gallery,
                    style: .bottomLeading,
                    screenW: screenW,
                    screenH: screenH,
                    safeAreaTop: geo.safeAreaInsets.top,
                    containerFrame: containerFrame
                )
            )

        case .gridGuide where context == .detail:
            TooltipView(
                title: "Grid Guide",
                description: "Tap to overlay the composition grid on your photo.",
                primaryLabel: nil,
                anchor: .topTrailing
            )
            .frame(width: min(screenW * 0.82, 340))
            .position(
                tooltipPosition(
                    for: .gridToggle,
                    style: .custom(
                        position: { containerW, cardWidth, localAnchor, _, estimatedCardHeight in
                            let tooltipCenterX = min(
                                containerW - cardWidth / 2 - Spacing.small,
                                max(localAnchor.midX, cardWidth / 2 + Spacing.small)
                            )
                            
                            return CGPoint(
                                x: tooltipCenterX + 2,
                                y: localAnchor.maxY + Spacing.small + estimatedCardHeight / 2 - 210
                            )
                        }
                    ),
                    screenW: screenW,
                    screenH: screenH,
                    safeAreaTop: geo.safeAreaInsets.top,
                    containerFrame: containerFrame
                )
            )

        case .hideGrid where context == .detail:
            TooltipView(
                title: "Hide Grid",
                description: "Tap here to turn off the grid and see the full image.",
                primaryLabel: nil,
                anchor: .topTrailing
            )
            .frame(width: min(screenW * 0.82, 340))
            .position(
                tooltipPosition(
                    for: .gridToggle,
                    style: .custom(
                        position: { containerW, cardWidth, localAnchor, _, estimatedCardHeight in
                            let tooltipCenterX = min(
                                containerW - cardWidth / 2 - Spacing.small,
                                max(localAnchor.midX, cardWidth / 2 + Spacing.small)
                            )
                            
                            return CGPoint(
                                x: tooltipCenterX + 2,
                                y: localAnchor.maxY + Spacing.small + estimatedCardHeight / 2 - 210
                            )
                        }
                    ),
                    screenW: screenW,
                    screenH: screenH,
                    safeAreaTop: geo.safeAreaInsets.top,
                    containerFrame: containerFrame
                )
            )

        case .congratulation where context == .detail:
            ZStack(alignment: .center) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()

                CongratulationView {
                    store.finishWalkthrough()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

        default:
            EmptyView()
        }
    }

    private func tooltipPosition(
        for anchorID: WalkthroughAnchorID,
        style: TooltipAnchor,
        screenW: CGFloat,
        screenH: CGFloat,
        safeAreaTop: CGFloat,
        containerFrame: CGRect
    ) -> CGPoint {
        if let anchor = anchors[anchorID] {
            return WalkthroughTooltipLayout.position(
                for: anchor,
                style: style,
                in: containerFrame
            )
        }

        return fallbackPosition(
            for: anchorID,
            screenW: screenW,
            screenH: screenH,
            safeAreaTop: safeAreaTop
        )
    }

    private func fallbackPosition(
        for anchorID: WalkthroughAnchorID,
        screenW: CGFloat,
        screenH: CGFloat,
        safeAreaTop: CGFloat = 0
    ) -> CGPoint {
        switch anchorID {
        case .guidanceTip:
            return CGPoint(x: screenW * 0.50, y: screenH * 0.22)
        case .shutter:
            return CGPoint(x: screenW * 0.50, y: screenH * 0.76)
        case .gallery:
            return CGPoint(
                x: min(screenW - Spacing.standard, WalkthroughTooltipLayout.estimatedCardWidth / 2 + Spacing.standard),
                y: screenH * 0.76
            )
        case .gridToggle:
            let cardWidth = min(screenW * 0.82, WalkthroughTooltipLayout.estimatedCardWidth)
            return CGPoint(
                x: screenW - cardWidth / 2 - Spacing.small,
                y: safeAreaTop + 22
            )
        }
    }
}

// MARK: - Preview

#Preview("Camera Walkthrough") {
    ZStack {
        Color.gray.ignoresSafeArea()
        WalkthroughOverlayView(context: .camera)
            .environment(OnboardingStore())
    }
}
