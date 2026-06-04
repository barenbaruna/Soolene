//
//  CompositionTechnique.swift
//  Photograph
//
//  Defines the 5 supported compositions, the ML prediction model,
//  and the GuidanceEngine that picks the best composition from
//  ML predictions + scene geometry, and generates directional tips.
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import CoreGraphics
import Foundation

// MARK: - CompositionType

/// The 5 composition types supported by FiveCompositionDetector.mlmodel.
enum CompositionType: String, CaseIterable, Identifiable, Codable {
    case ruleOfThirds = "Rule of Thirds"
    case center       = "Center"
    case horizontal   = "Horizontal"
    case vertical     = "Vertical"
    case diagonal     = "Diagonal"

    var id: String { rawValue }

    /// SF Symbol name for each composition.
    var symbolName: String {
        switch self {
        case .ruleOfThirds: return "rectangle.split.3x3"
        case .center:       return "scope"
        case .horizontal:   return "line.horizontal.3"
        case .vertical:     return "align.vertical.center"
        case .diagonal:     return "line.diagonal"
        }
    }

    /// Short description for onboarding or learning screens.
    var shortDescription: String {
        switch self {
        case .ruleOfThirds:
            return "Place key elements at the intersection of thirds lines."
        case .center:
            return "Position the subject directly in the center of the frame."
        case .horizontal:
            return "Align elements along horizontal lines for stability."
        case .vertical:
            return "Use vertical lines to create height and structure."
        case .diagonal:
            return "Follow diagonal lines for dynamic energy and movement."
        }
    }

    /// Maps a CoreML label string to a CompositionType.
    init?(coreMLLabel: String) {
        switch coreMLLabel.lowercased() {
        case "rule_of_thirds": self = .ruleOfThirds
        case "center":         self = .center
        case "horizontal":     self = .horizontal
        case "vertical":       self = .vertical
        case "diagonal":       self = .diagonal
        default:               return nil
        }
    }
}

// MARK: - CompositionPrediction

/// A single ML prediction result.
struct CompositionPrediction: Equatable {
    let type: CompositionType
    let confidence: Float
}

// MARK: - CompositionTechnique

/// The final recommendation shown to the user — a composition type and guidance tip.
struct CompositionTechnique: Identifiable, Equatable {
    let id = UUID()
    let composition: CompositionType
    let tip: String
}

// MARK: - GuidanceEngine

/// Picks the best composition from ML predictions combined with scene geometry,
/// then generates a precise directional guidance tip for the user.
///
/// How scoring works:
///   1. Takes Top-3 ML predictions (highest confidence first)
///   2. Adds geometry-based bonus scores per composition type
///   3. Picks the highest combined score
///   4. Generates a tip with directional arrows when a subject is detected
enum GuidanceEngine {

    // MARK: - Public API

    static func pickBest(
        predictions: [CompositionPrediction],
        geometry: SceneGeometry
    ) -> CompositionTechnique {
        guard !predictions.isEmpty else {
            return CompositionTechnique(
                composition: .ruleOfThirds,
                tip: "Point your camera at a scene to get started."
            )
        }

        // Score each prediction
        var bestType = predictions[0].type
        var bestScore: Float = -1

        for prediction in predictions.prefix(3) {
            let bonus = geometryBonus(for: prediction.type, geometry: geometry)
            let total = prediction.confidence + bonus
            if total > bestScore {
                bestScore = total
                bestType = prediction.type
            }
        }

        let tip = generateTip(for: bestType, geometry: geometry)
        return CompositionTechnique(composition: bestType, tip: tip)
    }

    // MARK: - Geometry Bonus

    /// Adds a bonus score based on what Vision APIs detect in the scene.
    /// These bonuses ensure the composition recommendation reflects actual scene content.
    private static func geometryBonus(
        for type: CompositionType,
        geometry: SceneGeometry
    ) -> Float {
        var bonus: Float = 0

        switch type {
        case .ruleOfThirds:
            // Face detected → portraits naturally suit Rule of Thirds
            if geometry.faceRect != nil { bonus += 0.15 }
            // Subject off-center → already in thirds territory
            if let centroid = geometry.saliencyCentroid {
                let offCenter = abs(centroid.x - 0.5) + abs(centroid.y - 0.5)
                if offCenter > 0.15 { bonus += 0.05 }
            }

        case .center:
            // Subject is near center of frame
            if let centroid = geometry.saliencyCentroid {
                let dist = hypot(centroid.x - 0.5, centroid.y - 0.5)
                if dist < 0.15 { bonus += 0.10 }
            }

        case .horizontal:
            // Scene has a detectable visual horizon (ocean, landscape, table line)
            // angle near zero = horizon is VISUAL and level
            if abs(geometry.horizonAngle) < 3.0 && geometry.horizonAngle != 0 {
                bonus += 0.08
            }

        case .vertical:
            // Scene has tall/narrow subject or strong vertical structures
            if geometry.hasStrongVerticals { bonus += 0.10 }
            if geometry.faceRect == nil, let bounds = geometry.saliencyBounds {
                if bounds.height > bounds.width * 1.3 { bonus += 0.08 }
            }

        case .diagonal:
            // A tilted visual horizon suggests diagonal composition
            if abs(geometry.horizonAngle) > 10.0 { bonus += 0.12 }
        }

        return bonus
    }

    // MARK: - Tip Generation

    /// Generates a concise, human-readable guidance tip.
    ///
    /// Design principles:
    /// - Simple, action-oriented text (≤5 words)
    /// - NO directional text arrows (→ ← ↑ ↓) — visual direction is handled
    ///   by CompositionDirectionOverlay which shows a bold arrow on the camera frame
    /// - Three states: (1) no data, (2) guiding, (3) aligned
    private static func generateTip(
        for type: CompositionType,
        geometry: SceneGeometry
    ) -> String {
        switch type {

        case .ruleOfThirds:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Place the main object on one of circle"
            }
            let targetX: CGFloat = centroid.x < 0.5 ? 0.33 : 0.67
            let targetY: CGFloat = centroid.y < 0.5 ? 0.33 : 0.67
            let dist = hypot(centroid.x - targetX, centroid.y - targetY)
            if dist < 0.08 { return "You're All Set" }
            if dist < 0.15 { return "Almost there!" }
            return "Place the main object on one of circle"

        case .center:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Place the main object inside the circle"
            }
            let dist = hypot(centroid.x - 0.5, centroid.y - 0.5)
            if dist < 0.08 { return "You're All Set" }
            if dist < 0.18 { return "Almost there!" }
            return "Place the main object inside the circle"

        case .horizontal:
            if geometry.horizonAngle == 0 {
                // No visual horizon detected yet
                return "Align the object with horizontal guide lines"
            }
            if abs(geometry.horizonAngle) < 2.0 { return "You're All Set" }
            if abs(geometry.horizonAngle) < 6.0 { return "Almost there!" }
            return "Align the object with horizontal guide lines"

        case .vertical:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Align the object with vertical guide lines"
            }
            let dist = abs(centroid.x - 0.5)
            if dist < 0.08 { return "You're All Set" }
            if dist < 0.16 { return "Almost there!" }
            return "Align the object with vertical guide lines"

        case .diagonal:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Make sure the scene is symmetrical"
            }
            let d1 = abs(centroid.y - centroid.x) / sqrt(2)
            let d2 = abs(centroid.y - (1 - centroid.x)) / sqrt(2)
            if min(d1, d2) < 0.08 { return "You're All Set" }
            if min(d1, d2) < 0.16 { return "Almost there!" }
            return "Make sure the scene is symmetrical"
        }
    }

    // MARK: - Helpers

    /// Returns the face bounding box center, or nil if no face is detected.
    private static func faceCenter(_ geometry: SceneGeometry) -> CGPoint? {
        guard let face = geometry.faceRect else { return nil }
        return CGPoint(x: face.midX, y: face.midY)
    }
}
