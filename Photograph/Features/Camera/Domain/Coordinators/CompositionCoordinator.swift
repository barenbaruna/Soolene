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

    init(visionService: VisionService, spatialEngine: SpatialCameraEngine) {
        self.visionService = visionService
        self.spatialEngine = spatialEngine
    }

    func resetGuidanceState() {
        uiState.isSubjectPinned = false
        visionService.clearPinnedSubject()
        uiState.phase = .scanning
        uiState.userSelectedComposition = nil
        uiState.mlSuggestion = nil
        uiState.recommendedLabel = nil
        visionService.isMLEnabled = true
    }

    func clearPinnedSubject(cameraMode: CameraMode) {
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
        }
    }

    func handleMLSuggestion(_ predictions: [CompositionPrediction], analysis: inout CompositionAnalysis) {
        guard case .subjectLocked = uiState.phase else { return }
        uiState.mlSuggestion = GuidanceEngine.suggestComposition(predictions: predictions)
        tryAutoSelect(predictions: predictions, analysis: &analysis)
    }

    func selectComposition(_ composition: CompositionType, analysis: inout CompositionAnalysis) {
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
                subjectAtLockTime: subject
            )
            analysis.sceneGeometry.lockedTargetPoint = frozenTarget
            visionService.syncGuidanceState(
                lockedTarget: frozenTarget,
                detectedComposition: composition
            )
        }
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
        guard let recommendation = GuidanceEngine.recommendForAutoSelect(predictions: predictions) else {
            visionService.isMLEnabled = true
            return
        }

        selectComposition(recommendation.type, analysis: &analysis)
        uiState.recommendedLabel = "Recommended: \(recommendation.type.shortLabel)"
    }
}
