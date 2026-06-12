//
//  CompositionCoordinator.swift
//  Photograph
//
//  Owns subject lock, composition selection, and guidance phase transitions.
//

import CoreGraphics
import UIKit

@MainActor
final class CompositionCoordinator {

    private let visionService: VisionService
    private let spatialEngine: SpatialCameraEngine

    var guidancePhase: GuidancePhase = .scanning
    var mlSuggestion: CompositionType? = nil
    var userSelectedComposition: CompositionType? = nil
    var isSubjectPinned = false
    var recommendedCompositionLabel: String? = nil

    init(visionService: VisionService, spatialEngine: SpatialCameraEngine) {
        self.visionService = visionService
        self.spatialEngine = spatialEngine
    }

    func resetGuidanceState() {
        isSubjectPinned = false
        visionService.clearPinnedSubject()
        guidancePhase = .scanning
        userSelectedComposition = nil
        mlSuggestion = nil
        recommendedCompositionLabel = nil
        visionService.isMLEnabled = true
    }

    func clearPinnedSubject(cameraMode: CameraMode) {
        HapticManager.selection()
        isSubjectPinned = false
        visionService.clearPinnedSubject()
        if cameraMode == .rearSpatial {
            spatialEngine.clearSubjectAnchor()
        }
        guidancePhase = .scanning
        userSelectedComposition = nil
        mlSuggestion = nil
        recommendedCompositionLabel = nil
        visionService.isMLEnabled = true
    }

    func pinSubject(
        at normalisedPoint: CGPoint,
        cameraMode: CameraMode,
        analysis: inout CompositionAnalysis
    ) {
        if isSubjectPinned {
            visionService.clearPinnedSubject()
            userSelectedComposition = nil
            mlSuggestion = nil
            recommendedCompositionLabel = nil
            analysis.mlPredictions = []
            analysis.detectedComposition = .ruleOfThirds
            visionService.resetScanningState()
        }

        let resolvedPoint = visionService.resolvedPinPoint(
            for: normalisedPoint,
            geometry: analysis.sceneGeometry
        )

        HapticManager.lock()
        isSubjectPinned = true
        visionService.pinSubject(at: resolvedPoint)
        if cameraMode == .rearSpatial {
            spatialEngine.lockSubject(at: resolvedPoint)
        }

        guidancePhase = .subjectLocked(subjectPoint: resolvedPoint)
        mlSuggestion = nil
        recommendedCompositionLabel = nil

        if !analysis.mlPredictions.isEmpty {
            mlSuggestion = GuidanceEngine.suggestComposition(predictions: analysis.mlPredictions)
            tryAutoSelect(predictions: analysis.mlPredictions, analysis: &analysis)
        } else {
            visionService.isMLEnabled = true
        }
    }

    func handleMLSuggestion(_ predictions: [CompositionPrediction], analysis: inout CompositionAnalysis) {
        guard case .subjectLocked = guidancePhase else { return }
        mlSuggestion = GuidanceEngine.suggestComposition(predictions: predictions)
        tryAutoSelect(predictions: predictions, analysis: &analysis)
    }

    func selectComposition(_ composition: CompositionType, analysis: inout CompositionAnalysis) {
        HapticManager.selection()
        userSelectedComposition = composition
        guidancePhase = .guiding(composition: composition)
        visionService.isMLEnabled = false
        analysis.detectedComposition = composition
        recommendedCompositionLabel = nil

        if let subject = analysis.sceneGeometry.smoothedSubjectPoint
                      ?? analysis.sceneGeometry.userPinnedSubject {
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
        if case .guiding(let comp) = guidancePhase {
            if analysis.isCompositionPerfect {
                guidancePhase = .perfect(composition: comp)
                HapticManager.notification(.success)
            }
        } else if case .perfect(let comp) = guidancePhase {
            if !analysis.isCompositionPerfect {
                guidancePhase = .guiding(composition: comp)
            }
        }
    }

    private func tryAutoSelect(predictions: [CompositionPrediction], analysis: inout CompositionAnalysis) {
        guard userSelectedComposition == nil else { return }
        guard let recommendation = GuidanceEngine.recommendForAutoSelect(predictions: predictions) else {
            visionService.isMLEnabled = true
            return
        }

        selectComposition(recommendation.type, analysis: &analysis)
        recommendedCompositionLabel = "Recommended: \(recommendation.type.shortLabel)"
    }
}
