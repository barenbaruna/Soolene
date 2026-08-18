//
//  GuidanceEngine.swift
//  Soolene
//
//  Selects the best composition from ML predictions and generates a guidance tip.
//
//  Design contract:
//  - The ML model (FiveCompositionDetector) is the sole authority on composition type.
//  - No geometry-based bonuses or rule overrides are applied here.
//  - Returns nil when no ML predictions are available, allowing the UI to show
//    a neutral "scanning" state rather than a potentially misleading default.
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import CoreGraphics
import Foundation

/// Converts raw ML predictions into a user-facing composition recommendation.
///
/// Responsibilities:
///   1. Picks the highest-confidence label from FiveCompositionDetector output.
///   2. Generates a concise guidance tip string for the selected composition.
///   3. Returns nil if the model has not produced any predictions yet.
enum GuidanceEngine {

    /// Minimum ML confidence required to auto-select a composition on subject lock.
    static let autoSelectConfidenceThreshold: Float = 0.55

    /// ML label must exceed the incumbent by this delta before switching during scanning.
    static let mlHysteresisMinDelta: Float = 0.20

    /// Frames a challenger label must persist before replacing the incumbent.
    static let mlHysteresisFrames = 15

    // MARK: - Public API

    /// Returns the best composition technique based on ML predictions alone.
    ///
    /// - Parameters:
    ///   - predictions: Top-N results from FiveCompositionDetector, sorted by confidence descending.
    ///   - geometry: Scene geometry used only to generate the tip text (not to re-rank predictions).
    /// - Returns: The recommended technique, or nil if predictions is empty.
    static func pickBest(
        predictions: [CompositionPrediction],
        geometry: SceneGeometry
    ) -> CompositionTechnique? {
        guard let top = predictions.first else { return nil }
        let tip = generateTip(for: top.type, geometry: geometry)
        return CompositionTechnique(composition: top.type, tip: tip)
    }

    /// Returns the ML-suggested composition type from predictions.
    /// Called ONCE when the user locks a subject — the result is shown
    /// as "★ Recommended" in the Composition Picker.
    ///
    /// Does NOT modify any app state. Pure function.
    static func suggestComposition(
        predictions: [CompositionPrediction]
    ) -> CompositionType? {
        predictions.first?.type
    }

    /// Returns the top recommendation when confidence meets the auto-select threshold.
    static func recommendForAutoSelect(
        predictions: [CompositionPrediction]
    ) -> (type: CompositionType, confidence: Float)? {
        guard let top = predictions.first,
              top.confidence >= autoSelectConfidenceThreshold
        else { return nil }
        return (top.type, top.confidence)
    }

    /// Returns the top ML prediction for immediate auto-select on subject lock.
    static func recommendForImmediateSelect(
        predictions: [CompositionPrediction]
    ) -> (type: CompositionType, confidence: Float)? {
        guard let top = predictions.first else { return nil }
        return (top.type, top.confidence)
    }

    /// Orders picker pills by ML confidence (highest first), then remaining types.
    static func sortedPickerOrder(predictions: [CompositionPrediction]) -> [CompositionType] {
        var seen = Set<CompositionType>()
        var ordered: [CompositionType] = []
        for prediction in predictions {
            if seen.insert(prediction.type).inserted {
                ordered.append(prediction.type)
            }
        }
        for type in CompositionType.allCases where !seen.contains(type) {
            ordered.append(type)
        }
        return ordered
    }

    /// Generates a technique for a user-selected composition.
    /// Used when the user picks from the Composition Picker.
    static func techniqueForUserSelection(
        composition: CompositionType,
        geometry: SceneGeometry
    ) -> CompositionTechnique {
        let tip = generateTip(for: composition, geometry: geometry)
        return CompositionTechnique(composition: composition, tip: tip)
    }

    // MARK: - Tip Generation

    /// Generates a concise, human-readable guidance tip for the given composition type.
    ///
    /// Tips describe the visual goal (where the subject should end up), not the physical action
    /// (do not use "move left/right"). The Dual-Anchor overlay handles spatial direction visually.
    private static func generateTip(
        for type: CompositionType,
        geometry: SceneGeometry
    ) -> String {
        switch type {

        case .ruleOfThirds:
            guard let subject = bestSubjectPoint(from: geometry) else {
                return "Tap your subject, then align the square with a circle."
            }
            if let locked = geometry.lockedTargetPoint {
                let dist = hypot(subject.x - locked.x, subject.y - locked.y)
                if dist < 0.06 { return "Perfect. Hold steady." }
                if dist < 0.15 { return "Almost there." }
                return "Align the square with the circle."
            }
            return "Align the square with a circle."

        case .center:
            guard let subject = bestSubjectPoint(from: geometry) else {
                return "Tap your subject, then move the square to the center."
            }
            let dist = hypot(subject.x - 0.5, subject.y - 0.5)
            if dist < 0.06 { return "Perfect. Hold steady." }
            if dist < 0.18 { return "Almost there." }
            return "Move the square to the center."

        case .horizontal:
            guard let subject = bestSubjectPoint(from: geometry) else {
                return "Tap your subject, then align the square with the horizontal line."
            }
            let target = AlignmentAnalyzer.targetPoint(for: .horizontal, subject: subject, geometry: geometry) ?? CGPoint(x: subject.x, y: 0.5)
            let dist = hypot(subject.x - target.x, subject.y - target.y)
            if dist < 0.06 { return "Perfect. Hold steady." }
            if dist < 0.16 { return "Almost there." }
            return "Align the square with the horizontal line."

        case .vertical:
            guard let subject = bestSubjectPoint(from: geometry) else {
                return "Tap your subject, then align the square with the vertical line."
            }
            let dist = abs(subject.x - 0.5)
            if dist < 0.06 { return "Perfect. Hold steady." }
            if dist < 0.16 { return "Almost there." }
            return "Align the square with the vertical line."

        case .diagonal:
            guard let subject = bestSubjectPoint(from: geometry) else {
                return "Tap your subject, then align the square with the diagonal line."
            }
            let d1 = abs(subject.y - subject.x) / sqrt(2)
            let d2 = abs(subject.y - (1 - subject.x)) / sqrt(2)
            let nearest = min(d1, d2)
            if nearest < 0.06 { return "Perfect. Hold steady." }
            if nearest < 0.16 { return "Almost there." }
            return "Align the square with the diagonal line."
        }
    }

    // MARK: - Helpers

    /// Resolves the best subject point from geometry using the standard priority chain.
    private static func bestSubjectPoint(from geometry: SceneGeometry) -> CGPoint? {
        if geometry.isSubjectLocked {
            return geometry.trackedSubjectPoint ?? geometry.userLockOrigin
        }
        if let face = geometry.faceRects.first {
            return CGPoint(x: face.midX, y: face.midY)
        }
        if let body = geometry.bodyCenter { return body }
        
        // Use objectness saliency (foreground objects) before falling back to attention saliency.
        // This dramatically improves accuracy for non-human subjects like animals or architecture.
        if let objectness = geometry.objectnessCentroid { return objectness }
        
        return geometry.saliencyCentroid
    }
}
