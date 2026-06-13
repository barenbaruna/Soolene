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

    /// Euclidean distance between subject and its target, in normalised 0–1 space.
    /// Used by the Dual-Anchor overlay to determine rendering state:
    ///   > 0.12  — Subject ring + target socket + faint connector line
    ///   0.06–0.12 — Connector hides, target socket expands and warms in colour
    ///   < 0.06  — Perfect snap: both anchors merge, turn green, haptic fires
    var guidanceDistance: CGFloat = 0

    /// True when the subject is at the ideal position for the chosen composition.
    var isCompositionPerfect: Bool = false

    // MARK: - ML Data Gate

    /// True once the ML model has returned at least one prediction for the current session.
    /// The Dual-Anchor overlay is suppressed until this becomes true to prevent false guidance
    /// during the initial ~2-second warm-up period before the slow-tier model runs.
    var hasMLData: Bool { !mlPredictions.isEmpty }

    // MARK: - Scene Alignment Quality

    /// How well the current scene matches the detected composition (0.0–1.0).
    ///
    /// - 0.0        — No Vision data yet            — draw WHITE guide lines
    /// - 0.01–0.79  — Vision data present, not yet aligned — draw RED guide lines
    /// - 0.80–1.0   — Scene is aligned              — draw GREEN guide lines
    ///
    /// Computed purely from scene/object Vision data (saliency, horizon, rectangles),
    /// not from device gyroscope or orientation sensors.
    var sceneAlignmentScore: Float = 0

    // MARK: - Overlay Color Decision

    /// True when Vision has returned usable scene data for the current composition.
    /// When false, guide lines are drawn in WHITE (neutral / no feedback mode).
    var hasSceneData: Bool {
        if sceneGeometry.isSubjectLocked { return true }
        switch detectedComposition {
        case .ruleOfThirds, .center, .diagonal:
            return sceneGeometry.saliencyCentroid != nil || !sceneGeometry.faceRects.isEmpty
        case .horizontal:
            return sceneGeometry.horizonDetected
                || sceneGeometry.deviceRollDegrees != nil
                || sceneGeometry.isSubjectLocked
        case .vertical:
            return sceneGeometry.saliencyBounds != nil || sceneGeometry.hasStrongVerticals
        }
    }

    // MARK: - Convenience Accessors

    var horizonAngle: Double { sceneGeometry.horizonAngle }
    var faceRects: [CGRect]  { sceneGeometry.faceRects }
    var saliencyCentroid: CGPoint? { sceneGeometry.saliencyCentroid }

    /// Priority when locked: smoothed > tracked > lock origin.
    /// When scanning: face > body > saliency.
    var bestSubjectPoint: CGPoint? {
        if sceneGeometry.isSubjectLocked {
            if let smoothed = sceneGeometry.smoothedSubjectPoint { return smoothed }
            return sceneGeometry.trackedSubjectPoint ?? sceneGeometry.userLockOrigin
        }
        if let face = sceneGeometry.faceRects.first {
            return CGPoint(x: face.midX, y: face.midY)
        }
        if let body = sceneGeometry.bodyCenter { return body }
        return sceneGeometry.saliencyCentroid
    }
}
