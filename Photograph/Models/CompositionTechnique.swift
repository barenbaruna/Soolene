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

    /// Generates a directional guidance tip telling the user WHERE to move the subject.
    ///
    /// Uses Unicode arrows (→ ← ↑ ↓) for compact, clear direction cues.
    /// Falls back to a generic instruction when no scene data is available.
    private static func generateTip(
        for type: CompositionType,
        geometry: SceneGeometry
    ) -> String {
        switch type {

        case .ruleOfThirds:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Place the main object on one of the circles"
            }
            let targetX: CGFloat = centroid.x < 0.5 ? 0.33 : 0.67
            let targetY: CGFloat = centroid.y < 0.5 ? 0.33 : 0.67
            let dist = hypot(centroid.x - targetX, centroid.y - targetY)
            if dist < 0.08 { return "You're All Set" }
            return directionTip(from: centroid, to: CGPoint(x: targetX, y: targetY),
                                prefix: "Place the main object on one of circle")

        case .center:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Place the main object inside the circle"
            }
            let dist = hypot(centroid.x - 0.5, centroid.y - 0.5)
            if dist < 0.08 { return "You're All Set" }
            return directionTip(from: centroid, to: CGPoint(x: 0.5, y: 0.5),
                                prefix: "Place the main object inside the circle")

        case .horizontal:
            // This is purely a VISUAL horizon check — not gyroscope
            if geometry.horizonAngle == 0 {
                return "Align the object with horizontal guide lines"
            }
            if abs(geometry.horizonAngle) < 2.0 { return "You're All Set" }
            let dir = geometry.horizonAngle > 0 ? "Tilt slightly ←" : "Tilt slightly →"
            return "Align the object with horizontal guide lines — \(dir)"

        case .vertical:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Align the object with vertical guide lines"
            }
            let dist = abs(centroid.x - 0.5)
            if dist < 0.08 { return "You're All Set" }
            let dir = centroid.x < 0.5 ? "Move subject →" : "Move subject ←"
            return "Align the object with vertical guide lines — \(dir)"

        case .diagonal:
            guard let centroid = geometry.saliencyCentroid ?? faceCenter(geometry) else {
                return "Make sure the scene is symmetrical"
            }
            let distToDiag1 = abs(centroid.y - centroid.x) / sqrt(2)
            let distToDiag2 = abs(centroid.y - (1 - centroid.x)) / sqrt(2)
            let minDist = min(distToDiag1, distToDiag2)
            if minDist < 0.08 { return "You're All Set" }
            return "Make sure the scene is symmetrical"
        }
    }

    // MARK: - Helpers

    /// Returns the center point of the face bounding box if one is detected.
    private static func faceCenter(_ geometry: SceneGeometry) -> CGPoint? {
        guard let face = geometry.faceRect else { return nil }
        return CGPoint(x: face.midX, y: face.midY)
    }

    /// Generates a directional tip string with a Unicode arrow.
    ///
    /// - Parameters:
    ///   - from: Current subject position (normalised 0–1)
    ///   - to: Target ideal position (normalised 0–1)
    ///   - prefix: The base instruction text
    private static func directionTip(
        from current: CGPoint,
        to target: CGPoint,
        prefix: String
    ) -> String {
        let dx = target.x - current.x  // + = right, - = left
        let dy = target.y - current.y  // + = down, - = up

        let absDx = abs(dx)
        let absDy = abs(dy)

        // Determine dominant direction
        if absDx < 0.04 && absDy < 0.04 {
            return prefix  // Almost there, just return the base instruction
        }

        var arrows: [String] = []

        if absDx > 0.04 { arrows.append(dx > 0 ? "→" : "←") }
        if absDy > 0.04 { arrows.append(dy > 0 ? "↓" : "↑") }

        let arrowText = arrows.joined(separator: " ")
        return "\(prefix) \(arrowText)"
    }
}
