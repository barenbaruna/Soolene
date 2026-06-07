//
//  WalkthroughOverlayView.swift
//  Photograph
//
//  Renders walkthrough tooltips precisely on the camera & detail views.
//
//  Tooltip positions (1:1 with Hi-Fi mockups):
//  ┌─────────────────────────────────┐
//  │ Step 1: Composition Suggestion  │  → Left of overlay circle, pointing at guides
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
    @EnvironmentObject private var manager: OnboardingManager
    let context: WalkthroughContext

    var body: some View {
        if manager.isWalkthroughActive {
            GeometryReader { geo in
                ZStack {
                    tooltipForCurrentStep(in: geo)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Step Router

    @ViewBuilder
    private func tooltipForCurrentStep(in geo: GeometryProxy) -> some View {
        let screenW = geo.size.width
        let screenH = geo.size.height

        switch manager.currentStep {

        // ── Step 1: Composition Suggestion ────────────────
        // Left side, vertically centered near the overlay circle
        case .compositionSuggestion where context == .camera:
            TooltipView(
                title: "Composition Suggestion",
                description: "Get composition recommendations based on the scene in your camera and follow the on-screen guides",
                anchor: .bottom,
                onPrimary: { manager.advanceStep() },
                onSecondary: { manager.skipWalkthrough() }
            )
            .frame(width: min(screenW * 0.72, 280))
            .position(x: screenW * 0.40, y: screenH * 0.38)

        // ── Step 2: Follow the Guide ─────────────────────
        // Below the guidance tip pill, horizontally centered
        case .followGuide where context == .camera:
            TooltipView(
                title: "Follow the Guide",
                description: "Follow the on-screen directions and adjust your framing",
                anchor: .top,
                onPrimary: { manager.advanceStep() },
                onSecondary: { manager.skipWalkthrough() }
            )
            .frame(width: min(screenW * 0.72, 280))
            .position(x: screenW * 0.50, y: screenH * 0.32)

        // ── Step 3: Ready to Shoot ───────────────────────
        // Just above the capture button (bottom center)
        case .readyToShoot where context == .camera:
            TooltipView(
                title: "Ready to Shoot",
                description: "Tap this button to capture your photo once you've lined up the perfect composition guidelines.",
                anchor: .bottom,
                onPrimary: { manager.advanceStep() },
                onSecondary: { manager.skipWalkthrough() }
            )
            .frame(width: min(screenW * 0.80, 320))
            .position(x: screenW * 0.50, y: screenH * 0.72)

        // ── Step 4: View Your Shots ──────────────────────
        // Above the gallery thumbnail (bottom-left corner)
        case .viewShots where context == .camera:
            TooltipView(
                title: "View Your Shots",
                description: "Tap here to view and review all the photos you have captured using the composition guides.",
                anchor: .bottomLeading,
                onPrimary: { manager.advanceStep() },
                onSecondary: { manager.skipWalkthrough() }
            )
            .frame(width: min(screenW * 0.68, 260))
            .position(x: screenW * 0.38, y: screenH * 0.72)

        // ── Step 5: Grid Guide ───────────────────────────
        // Below the grid toggle button (top-right of detail view)
        case .gridGuide where context == .detail:
            TooltipView(
                title: "Grid Guide",
                description: "Tap to overlay the composition grid on your photo.",
                anchor: .top,
                onPrimary: { manager.advanceStep() },
                onSecondary: { manager.skipWalkthrough() }
            )
            .frame(width: min(screenW * 0.72, 280))
            .position(x: screenW * 0.60, y: screenH * 0.18)

        // ── Step 6: Hide Grid ────────────────────────────
        // Same position as grid guide
        case .hideGrid where context == .detail:
            TooltipView(
                title: "Hide Grid",
                description: "Tap here to turn off the grid and see the full image.",
                primaryLabel: "Finish",
                secondaryLabel: nil,
                anchor: .top,
                onPrimary: { manager.advanceStep() },
                onSecondary: nil
            )
            .frame(width: min(screenW * 0.72, 280))
            .position(x: screenW * 0.60, y: screenH * 0.18)

        // ── Step 7: Congratulation ───────────────────────
        // Centered card
        case .congratulation where context == .detail:
            CongratulationView {
                manager.finishWalkthrough()
            }
            .position(x: screenW * 0.50, y: screenH * 0.50)

        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Camera Walkthrough") {
    ZStack {
        Color.gray.ignoresSafeArea()
        WalkthroughOverlayView(context: .camera)
            .environmentObject(OnboardingManager())
    }
}
