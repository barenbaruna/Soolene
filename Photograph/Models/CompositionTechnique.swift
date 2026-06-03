//
//  CompositionTechnique.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import CoreGraphics
import Foundation

// MARK: - CompositionType (5 compositions only)

/// The 5 composition types supported by FiveCompositionDetector.mlmodel.
enum CompositionType: String, CaseIterable, Identifiable, Codable {
    case ruleOfThirds = "Rule of Thirds"
    case center = "Center"
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case diagonal = "Diagonal"

    var id: String { rawValue }

    /// SF Symbol for each composition.
    var symbolName: String {
        switch self {
        case .ruleOfThirds: return "grid.3x3"
        case .center: return "scope"
        case .horizontal: return "line.horizontal.3"
        case .vertical: return "line.vertical.3"
        case .diagonal: return "line.diagonal"
        }
    }

    /// Short description for learning.
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

    /// Maps CoreML label string to CompositionType.
    init?(coreMLLabel: String) {
        switch coreMLLabel.lowercased() {
        case "rule_of_thirds": self = .ruleOfThirds
        case "center": self = .center
        case "horizontal": self = .horizontal
        case "vertical": self = .vertical
        case "diagonal": self = .diagonal
        default: return nil
        }
    }
}

// MARK: - ML Prediction

/// A single ML prediction with its confidence score.
struct CompositionPrediction: Equatable {
    let type: CompositionType
    let confidence: Float
}

// MARK: - CompositionTechnique (UI display)

/// The final recommendation shown to the user.
struct CompositionTechnique: Identifiable, Equatable {
    let id = UUID()
    let composition: CompositionType
    let tip: String
}

// MARK: - GuidanceEngine

/// Picks the best composition from ML predictions + scene geometry.
///
/// How it works:
/// 1. Takes Top-3 ML predictions from FiveCompositionDetector
/// 2. Adds geometry-based bonus scores (face → Rule of Thirds, level horizon → Horizontal, etc.)
/// 3. The composition with the highest combined score wins
/// 4. Generates a human-readable guidance tip
enum GuidanceEngine {

    /// Picks the best composition and generates guidance.
    /// - Parameters:
    ///   - predictions: Top-3 ML predictions sorted by confidence (highest first)
    ///   - geometry: Real-time scene geometry from Vision APIs
    /// - Returns: The chosen CompositionTechnique with guidance tip
    static func pickBest(
        predictions: [CompositionPrediction],
        geometry: SceneGeometry
    ) -> CompositionTechnique {
        guard !predictions.isEmpty else {
            return CompositionTechnique(
                composition: .ruleOfThirds,
                tip: "Point your camera at a scene to get guidance."
            )
        }

        // Score each prediction: ML confidence + geometry bonus
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

    /// Adds bonus score based on what Vision APIs detect in the scene.
    private static func geometryBonus(for type: CompositionType, geometry: SceneGeometry) -> Float {
        var bonus: Float = 0

        switch type {
        case .ruleOfThirds:
            // Face detected → strong bonus (portraits suit Rule of Thirds)
            if geometry.faceRect != nil { bonus += 0.15 }
            // Subject off-center → bonus (already positioned for thirds)
            if let centroid = geometry.saliencyCentroid {
                let offCenter = abs(centroid.x - 0.5) + abs(centroid.y - 0.5)
                if offCenter > 0.15 { bonus += 0.05 }
            }

        case .center:
            // Subject near center → bonus
            if let centroid = geometry.saliencyCentroid {
                let dist = hypot(centroid.x - 0.5, centroid.y - 0.5)
                if dist < 0.15 { bonus += 0.10 }
            }

        case .horizontal:
            // Horizon is level → bonus (scene has strong horizontal lines)
            if abs(geometry.horizonAngle) < 3.0 { bonus += 0.08 }

        case .vertical:
            // No face + saliency tall and narrow → bonus
            if geometry.faceRect == nil, let bounds = geometry.saliencyBounds {
                if bounds.height > bounds.width * 1.3 { bonus += 0.08 }
            }

        case .diagonal:
            // Phone is tilted → bonus (user is experimenting with angles)
            if abs(geometry.horizonAngle) > 10.0 { bonus += 0.12 }
        }

        return bonus
    }

    // MARK: - Tip Generation

    /// Generates a contextual guidance tip.
    private static func generateTip(for type: CompositionType, geometry: SceneGeometry) -> String {
        // Horizon warning takes priority if severely tilted
        if abs(geometry.horizonAngle) > 5.0 && type != .diagonal {
            return "Level the horizon (\(String(format: "%.0f", abs(geometry.horizonAngle)))° tilt)."
        }

        switch type {
        case .ruleOfThirds:
            guard let centroid = geometry.saliencyCentroid else {
                return "Align subject with grid intersections."
            }
            let closestX: CGFloat = centroid.x < 0.5 ? 0.33 : 0.67
            let closestY: CGFloat = centroid.y < 0.5 ? 0.33 : 0.67
            let dist = hypot(centroid.x - closestX, centroid.y - closestY)
            if dist < 0.08 {
                return "Perfectly aligned."
            }
            return "Align subject with grid intersections."

        case .center:
            guard let centroid = geometry.saliencyCentroid else {
                return "Center the subject."
            }
            let dist = hypot(centroid.x - 0.5, centroid.y - 0.5)
            if dist < 0.08 {
                return "Subject centered."
            }
            return "Center the subject."

        case .horizontal:
            if abs(geometry.horizonAngle) < 2.0 {
                return "Horizon leveled."
            }
            return "Level the camera."

        case .vertical:
            return "Align subject vertically."

        case .diagonal:
            if abs(geometry.horizonAngle) > 10.0 {
                return "Dynamic angle."
            }
            return "Follow diagonal lines."
        }
    }
}
