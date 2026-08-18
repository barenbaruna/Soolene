//
//  OnboardingStore.swift
//  Soolene
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
        static let completedSplash = "soolene_hasCompletedSplash"
        static let completedPreTutorialOnboarding = "soolene_hasCompletedPreTutorialOnboarding"
        static let completedWalkthrough = "soolene_hasCompletedWalkthrough"
        static let scanCoachSessions = "coach.scanSessionsShown"
        static let hasLockedSubjectOnce = "coach.hasLockedSubjectOnce"
    }

    var hasCompletedSplash: Bool {
        didSet { UserDefaults.standard.set(hasCompletedSplash, forKey: StorageKey.completedSplash) }
    }

    var hasCompletedPreTutorialOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(
                hasCompletedPreTutorialOnboarding,
                forKey: StorageKey.completedPreTutorialOnboarding
            )
        }
    }

    var hasCompletedWalkthrough: Bool {
        didSet { UserDefaults.standard.set(hasCompletedWalkthrough, forKey: StorageKey.completedWalkthrough) }
    }

    var currentStep: WalkthroughStep = .compositionSuggestion
    var walkthroughPhotoIdentifier: String?

    var isWalkthroughActive: Bool {
        !hasCompletedWalkthrough
    }

    var allowsSceneLock: Bool {
        !isWalkthroughActive || currentStep == .compositionSuggestion
    }

    var allowsCameraFocusControls: Bool {
        !isWalkthroughActive
    }

    var allowsCameraToolbar: Bool {
        !isWalkthroughActive
    }

    var allowsCompositionControls: Bool {
        !isWalkthroughActive
    }

    var allowsShutter: Bool {
        !isWalkthroughActive || currentStep == .readyToShoot
    }

    var allowsGalleryButton: Bool {
        !isWalkthroughActive || currentStep == .viewShots
    }

    var allowsCameraSwitch: Bool {
        !isWalkthroughActive
    }

    var allowsGalleryBrowsing: Bool {
        !isWalkthroughActive
    }

    var allowsPhotoDetailExit: Bool {
        !isWalkthroughActive
    }

    var allowsPhotoDelete: Bool {
        !isWalkthroughActive
    }

    var allowsPhotoGridToggle: Bool {
        !isWalkthroughActive || currentStep == .gridGuide || currentStep == .hideGrid
    }

    var shouldAutoOpenRecentPhoto: Bool {
        isWalkthroughActive && currentStep == .gridGuide
    }

    /// Subtle center viewfinder hint for the first two post-walkthrough scanning sessions.
    var showsScanningViewfinderHint: Bool {
        hasCompletedWalkthrough && scanCoachSessionsShown < 2
    }

    /// Increments after walkthrough when the user enters a new scanning session.
    private(set) var scanCoachSessionsShown: Int

    /// Set after the user locks a subject for the first time (TipKit gating).
    private(set) var hasLockedSubjectOnce: Bool

    init() {
        let completedSplash = UserDefaults.standard.bool(forKey: StorageKey.completedSplash)
        let completedWalkthrough = UserDefaults.standard.bool(forKey: StorageKey.completedWalkthrough)
        let completedPreTutorialOnboarding = UserDefaults.standard.bool(
            forKey: StorageKey.completedPreTutorialOnboarding
        ) || completedWalkthrough

        hasCompletedSplash = completedSplash
        hasCompletedWalkthrough = completedWalkthrough
        hasCompletedPreTutorialOnboarding = completedPreTutorialOnboarding
        scanCoachSessionsShown = UserDefaults.standard.integer(forKey: StorageKey.scanCoachSessions)
        hasLockedSubjectOnce = UserDefaults.standard.bool(forKey: StorageKey.hasLockedSubjectOnce)
        if completedWalkthrough {
            currentStep = .congratulation
        }
    }

    func recordScanningCoachSession() {
        guard hasCompletedWalkthrough else { return }
        guard scanCoachSessionsShown < 2 else { return }
        scanCoachSessionsShown += 1
        UserDefaults.standard.set(scanCoachSessionsShown, forKey: StorageKey.scanCoachSessions)
    }

    func recordFirstSubjectLock() {
        guard !hasLockedSubjectOnce else { return }
        hasLockedSubjectOnce = true
        UserDefaults.standard.set(true, forKey: StorageKey.hasLockedSubjectOnce)
    }

    func advanceAfterSceneLock() {
        guard isWalkthroughActive, currentStep == .compositionSuggestion else { return }
        advanceStep()
    }

    func advanceAfterGuideCompletion() {
        guard isWalkthroughActive, currentStep == .followGuide else { return }
        advanceStep()
    }

    func advanceAfterCapture() {
        guard isWalkthroughActive, currentStep == .readyToShoot else { return }
        advanceStep()
    }

    func advanceAfterOpeningGallery() {
        guard isWalkthroughActive, currentStep == .viewShots else { return }
        advanceStep()
    }

    func recordWalkthroughPhotoIdentifier(_ identifier: String) {
        guard isWalkthroughActive else { return }
        walkthroughPhotoIdentifier = identifier
    }

    func advanceAfterGridToggle(isShowingOverlay: Bool) {
        guard isWalkthroughActive else { return }
        if currentStep == .gridGuide, isShowingOverlay {
            advanceStep()
        } else if currentStep == .hideGrid, !isShowingOverlay {
            advanceStep()
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

    func completePreTutorialOnboarding() {
        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedPreTutorialOnboarding = true
        }
    }

    func skipWalkthrough() {
        finishWalkthrough()
    }

    func finishWalkthrough() {
        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedWalkthrough = true
            walkthroughPhotoIdentifier = nil
        }
    }
}
