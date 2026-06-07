//
//  OnboardingManager.swift
//  Photograph
//
//  Manages the entire onboarding lifecycle:
//  Splash → Permissions → Walkthrough (7 steps) → Main App
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import Combine
import SwiftUI

// MARK: - Walkthrough Steps

/// Each step maps 1:1 to a tooltip in the Hi-Fi mockup.
enum WalkthroughStep: Int, CaseIterable {
    case compositionSuggestion = 0  // Points at composition overlay
    case followGuide           = 1  // Points at guidance tip text
    case readyToShoot          = 2  // Points at capture button
    case viewShots             = 3  // Points at gallery thumbnail
    case gridGuide             = 4  // Points at grid toggle (detail view)
    case hideGrid              = 5  // Same button, toggled on
    case congratulation        = 6  // Center alert with "Start" CTA
}

// MARK: - OnboardingManager

@MainActor
final class OnboardingManager: ObservableObject {

    // MARK: Persisted State

    @AppStorage("visula_hasCompletedSplash") var hasCompletedSplash = false
    @AppStorage("visula_hasCompletedWalkthrough") var hasCompletedWalkthrough = false

    // MARK: Published State

    @Published var currentStep: WalkthroughStep = .compositionSuggestion

    /// True while the walkthrough is active and incomplete.
    var isWalkthroughActive: Bool {
        !hasCompletedWalkthrough
    }

    // MARK: Init

    init() {
        if hasCompletedWalkthrough {
            currentStep = .congratulation
        }
    }

    // MARK: Actions

    /// Move to the next tooltip step.
    func advanceStep() {
        guard let next = WalkthroughStep(rawValue: currentStep.rawValue + 1) else {
            finishWalkthrough()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = next
        }
    }

    /// Skip the entire walkthrough and go straight to the main app.
    func skipWalkthrough() {
        finishWalkthrough()
    }

    /// Called when the user taps "Start" on the congratulation screen.
    func finishWalkthrough() {
        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedWalkthrough = true
        }
    }
}
