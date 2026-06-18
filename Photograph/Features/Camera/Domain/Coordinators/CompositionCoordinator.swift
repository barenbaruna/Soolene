//
//  CompositionCoordinator.swift
//  Photograph
//

import CoreGraphics
import SwiftUI
import UIKit

/// Subject lock, composition selection, and guidance phase transitions.
@MainActor
@Observable
final class CompositionCoordinator {

    private let visionService: VisionService
    private let spatialEngine: SpatialCameraEngine

    var uiState = CompositionUIState()

    private var autoSelectFallbackTask: Task<Void, Never>?
    private var sessionStartTime: Date?
    /// Invoked when ML predictions are delayed; ViewModel applies composition to analysis.
    var onAutoSelectComposition: (@MainActor (CompositionType) -> Void)?

    init(visionService: VisionService, spatialEngine: SpatialCameraEngine) {
        self.visionService = visionService
        self.spatialEngine = spatialEngine
    }

    func resetGuidanceState() {
        cancelAutoSelectFallback()
        uiState.isSubjectPinned = false
        visionService.clearPinnedSubject()
        uiState.phase = .scanning
        uiState.userSelectedComposition = nil
        uiState.mlSuggestion = nil
        uiState.recommendedLabel = nil
        visionService.isMLEnabled = true
    }

    func clearPinnedSubject(cameraMode: CameraMode) {
        cancelAutoSelectFallback()
        HapticManager.selection()
        uiState.isSubjectPinned = false
        visionService.clearPinnedSubject()
        if cameraMode == .rearSpatial {
            spatialEngine.clearSubjectAnchor()
        }
        uiState.phase = .scanning
        uiState.userSelectedComposition = nil
        uiState.mlSuggestion = nil
        uiState.recommendedLabel = nil
        visionService.isMLEnabled = true
    }

    func pinSubject(
        at normalisedPoint: CGPoint,
        cameraMode: CameraMode,
        analysis: inout CompositionAnalysis
    ) {
        sessionStartTime = Date()

        if uiState.isSubjectPinned {
            visionService.clearPinnedSubject()
            uiState.userSelectedComposition = nil
            uiState.mlSuggestion = nil
            uiState.recommendedLabel = nil
            analysis.mlPredictions = []
            analysis.detectedComposition = .ruleOfThirds
            visionService.resetScanningState()
        }

        let resolvedPoint = visionService.resolvedPinPoint(
            for: normalisedPoint,
            geometry: analysis.sceneGeometry
        )

        HapticManager.lock()
        uiState.isSubjectPinned = true
        visionService.pinSubject(at: resolvedPoint)
        if cameraMode == .rearSpatial {
            spatialEngine.lockSubject(at: resolvedPoint)
        }

        uiState.phase = .subjectLocked(subjectPoint: resolvedPoint)
        uiState.mlSuggestion = nil
        uiState.recommendedLabel = nil

        if !analysis.mlPredictions.isEmpty {
            uiState.mlSuggestion = GuidanceEngine.suggestComposition(predictions: analysis.mlPredictions)
            tryAutoSelect(predictions: analysis.mlPredictions, analysis: &analysis)
        } else {
            visionService.isMLEnabled = true
            scheduleAutoSelectFallback()
        }
    }

    func handleMLSuggestion(_ predictions: [CompositionPrediction], analysis: inout CompositionAnalysis) {
        guard case .subjectLocked = uiState.phase else { return }
        uiState.mlSuggestion = GuidanceEngine.suggestComposition(predictions: predictions)
        tryAutoSelect(predictions: predictions, analysis: &analysis)
    }

    func selectComposition(
        _ composition: CompositionType,
        analysis: inout CompositionAnalysis,
        aspectRatio: AspectRatioMode = .fourThree,
        orientation: UIDeviceOrientation = UIDevice.current.orientation
    ) {
        cancelAutoSelectFallback()
        HapticManager.selection()
        uiState.userSelectedComposition = composition
        uiState.phase = .guiding(composition: composition)
        visionService.isMLEnabled = false
        analysis.detectedComposition = composition
        uiState.recommendedLabel = nil

        if let subject = analysis.sceneGeometry.userLockOrigin
                      ?? analysis.sceneGeometry.trackedSubjectPoint {
            let frozenTarget = AlignmentAnalyzer.computeFixedTarget(
                for: composition,
                subjectAtLockTime: subject,
                aspectRatio: aspectRatio,
                orientation: orientation
            )
            analysis.sceneGeometry.lockedTargetPoint = frozenTarget
            visionService.syncGuidanceState(
                lockedTarget: frozenTarget,
                detectedComposition: composition
            )
        }
    }

    /// Recalculates the locked target point for the current composition
    /// when the user changes aspect ratio or device orientation while guidance is active.
    func recalculateTargetForAspectRatio(
        _ aspectRatio: AspectRatioMode,
        orientation: UIDeviceOrientation = UIDevice.current.orientation,
        analysis: inout CompositionAnalysis
    ) {
        guard let composition = uiState.userSelectedComposition else { return }

        let isGuidingOrPerfect: Bool
        switch uiState.phase {
        case .guiding, .perfect: isGuidingOrPerfect = true
        default: isGuidingOrPerfect = false
        }
        guard isGuidingOrPerfect else { return }

        guard let subject = analysis.sceneGeometry.userLockOrigin
                          ?? analysis.sceneGeometry.trackedSubjectPoint else { return }

        let newTarget = AlignmentAnalyzer.computeFixedTarget(
            for: composition,
            subjectAtLockTime: subject,
            aspectRatio: aspectRatio,
            orientation: orientation
        )
        analysis.sceneGeometry.lockedTargetPoint = newTarget
        visionService.syncGuidanceState(
            lockedTarget: newTarget,
            detectedComposition: composition
        )
    }

    func sortedPickerCompositions(predictions: [CompositionPrediction]) -> [CompositionType] {
        GuidanceEngine.sortedPickerOrder(predictions: predictions)
    }

    func updatePhaseFromAnalysis(_ analysis: CompositionAnalysis) {
        if case .guiding(let comp) = uiState.phase {
            if analysis.isCompositionPerfect {
                uiState.phase = .perfect(composition: comp)
                HapticManager.notification(.success)
            }
        } else if case .perfect(let comp) = uiState.phase {
            if !analysis.isCompositionPerfect {
                uiState.phase = .guiding(composition: comp)
            }
        }
    }

    private func tryAutoSelect(predictions: [CompositionPrediction], analysis: inout CompositionAnalysis) {
        guard uiState.userSelectedComposition == nil else { return }
        cancelAutoSelectFallback()

        guard let recommendation = GuidanceEngine.recommendForImmediateSelect(predictions: predictions) else {
            visionService.isMLEnabled = true
            scheduleAutoSelectFallback()
            return
        }

        let duration = sessionStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        print("📸 [ML] Recommendation=\(recommendation.type) Confidence=\(recommendation.confidence) Duration=\(duration)ms")

        selectComposition(
            recommendation.type,
            analysis: &analysis,
            aspectRatio: visionService.activeAspectRatio,
            orientation: visionService.activeDeviceOrientation
        )
        if recommendation.confidence >= GuidanceEngine.autoSelectConfidenceThreshold {
            uiState.recommendedLabel = "Recommended: \(recommendation.type.shortLabel)"
        } else {
            uiState.recommendedLabel = "Suggested: \(recommendation.type.shortLabel) — tap to change"
        }
    }

    private func scheduleAutoSelectFallback() {
        cancelAutoSelectFallback()
        autoSelectFallbackTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            guard case .subjectLocked = uiState.phase else { return }
            guard uiState.userSelectedComposition == nil else { return }

            let duration = sessionStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
            print("📸 [Fallback] Recommendation=ruleOfThirds Duration=\(duration)ms")

            uiState.mlSuggestion = .ruleOfThirds
            onAutoSelectComposition?(.ruleOfThirds)
            uiState.recommendedLabel = "Suggested: Rule of Thirds — tap to change"
        }
    }

    private func cancelAutoSelectFallback() {
        autoSelectFallbackTask?.cancel()
        autoSelectFallbackTask = nil
    }
}
