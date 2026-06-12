//
//  OnboardingStore.swift
//  Photograph
//

import SwiftUI

/// Walkthrough steps shown as tooltips on camera and photo detail screens.
enum WalkthroughStep: Int, CaseIterable {
    case compositionSuggestion = 0
    case followGuide = 1
    case readyToShoot = 2
    case viewShots = 3
    case gridGuide = 4
    case hideGrid = 5
    case congratulation = 6
}

/// Splash and first-run walkthrough state.
@MainActor
@Observable
final class OnboardingStore {
    private enum StorageKey {
        static let completedSplash = "visula_hasCompletedSplash"
        static let completedWalkthrough = "visula_hasCompletedWalkthrough"
    }

    var hasCompletedSplash: Bool {
        didSet { UserDefaults.standard.set(hasCompletedSplash, forKey: StorageKey.completedSplash) }
    }

    var hasCompletedWalkthrough: Bool {
        didSet { UserDefaults.standard.set(hasCompletedWalkthrough, forKey: StorageKey.completedWalkthrough) }
    }

    var currentStep: WalkthroughStep = .compositionSuggestion

    var isWalkthroughActive: Bool {
        !hasCompletedWalkthrough
    }

    init() {
        hasCompletedSplash = UserDefaults.standard.bool(forKey: StorageKey.completedSplash)
        hasCompletedWalkthrough = UserDefaults.standard.bool(forKey: StorageKey.completedWalkthrough)
        if hasCompletedWalkthrough {
            currentStep = .congratulation
        }
    }

    func advanceStep() {
        guard let next = WalkthroughStep(rawValue: currentStep.rawValue + 1) else {
            finishWalkthrough()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = next
        }
    }

    func skipWalkthrough() {
        finishWalkthrough()
    }

    func finishWalkthrough() {
        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedWalkthrough = true
        }
    }
}
