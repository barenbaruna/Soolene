//
//  CompositionAnalysis.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import CoreGraphics
import Foundation

/// Assembled result from the Vision analysis pipeline.
/// Built on the Vision queue, delivered to ViewModel on the main queue.
struct CompositionAnalysis: Equatable {

    /// Full geometric data from Vision APIs (saliency, horizon, face).
    var sceneGeometry = SceneGeometry()

    /// Composition score 0–100 (from iOS 18+ aesthetic API).
    var compositionScore: Int = 0

    /// Top-3 ML predictions from FiveCompositionDetector.
    var mlPredictions: [CompositionPrediction] = []

    /// The final chosen composition (after GuidanceEngine scoring).
    var detectedComposition: CompositionType = .ruleOfThirds

    /// The active tip to display in the UI banner.
    var activeTechnique: CompositionTechnique? = nil

    /// Distance vector from subject to ideal point. Used for UI feedback.
    var subjectOffset: CGVector = .zero

    /// True when the subject is at the ideal position.
    var isCompositionPerfect: Bool = false

    // MARK: - Convenience

    var horizonAngle: Double { sceneGeometry.horizonAngle }
    var faceRect: CGRect? { sceneGeometry.faceRect }
    var saliencyCentroid: CGPoint? { sceneGeometry.saliencyCentroid }
}
