//
//  CompositionAnalysis.swift
//  Photograph
//
//  Assembled result from the Vision analysis pipeline.
//  Built on the Vision queue, delivered to ViewModel on the main queue.
//
//  Note: SceneGeometry is defined in SceneGeometry.swift.
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import CoreGraphics
import Foundation

// MARK: - CompositionAnalysis

/// The full output of the Vision pipeline for one frame.
struct CompositionAnalysis: Equatable {

    /// Full geometric data from Vision APIs.
    var sceneGeometry = SceneGeometry()

    /// Top-3 ML predictions from FiveCompositionDetector.
    var mlPredictions: [CompositionPrediction] = []

    /// The final chosen composition (after GuidanceEngine scoring).
    var detectedComposition: CompositionType = .ruleOfThirds

    /// The active tip to display in the guidance pill.
    var activeTechnique: CompositionTechnique? = nil

    /// Normalised direction vector from subject to its ideal position (0–1 space).
    /// .zero means the subject is already at the ideal position.
    var subjectOffset: CGVector = .zero

    /// True when the subject is at the ideal position for the chosen composition.
    var isCompositionPerfect: Bool = false

    // MARK: - Scene Alignment Quality

    /// How well the current scene matches the detected composition (0.0–1.0).
    ///
    /// - 0.0        → No Vision data yet            → draw WHITE guide lines
    /// - 0.01–0.79  → Vision data present, not yet aligned → draw RED guide lines
    /// - 0.80–1.0   → Scene is aligned              → draw GREEN guide lines
    ///
    /// Computed purely from scene/object Vision data (saliency, horizon, rectangles),
    /// NOT from device gyroscope or orientation sensors.
    var sceneAlignmentScore: Float = 0

    // MARK: - Overlay Color Decision

    /// True when Vision has returned usable scene data for the current composition.
    /// When false, guide lines are drawn in WHITE (neutral / no feedback mode).
    var hasSceneData: Bool {
        switch detectedComposition {
        case .ruleOfThirds, .center, .diagonal:
            return sceneGeometry.saliencyCentroid != nil || sceneGeometry.faceRect != nil
        case .horizontal:
            // VNDetectHorizonRequest sets angle to 0 when no horizon is found
            return sceneGeometry.horizonAngle != 0
        case .vertical:
            return sceneGeometry.saliencyBounds != nil || sceneGeometry.hasStrongVerticals
        }
    }

    // MARK: - Convenience Accessors

    var horizonAngle: Double { sceneGeometry.horizonAngle }
    var faceRect: CGRect?    { sceneGeometry.faceRect }
    var saliencyCentroid: CGPoint? { sceneGeometry.saliencyCentroid }

    /// The best available subject position in normalised coordinates (0–1, UIKit).
    /// Uses the same priority chain as VisionService: face > body > saliency
    var bestSubjectPoint: CGPoint? {
        if let face = sceneGeometry.faceRect {
            return CGPoint(x: face.midX, y: face.midY)
        }
        if let body = sceneGeometry.bodyCenter {
            return body
        }
        return sceneGeometry.saliencyCentroid
    }
}
