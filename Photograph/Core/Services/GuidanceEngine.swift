//
//  GuidanceEngine.swift
//  Photograph
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
            let angle = abs(geometry.horizonAngle)
            if geometry.horizonAngle == 0 { return "Level the camera." }
            if angle < 2.0 { return "Perfect. Hold steady." }
            if angle < 6.0 { return "Almost there." }
            return "Level the camera."

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
        if let pinned = geometry.userPinnedSubject { return pinned }
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
