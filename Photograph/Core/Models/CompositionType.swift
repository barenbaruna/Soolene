//
//  CompositionType.swift
//  Photograph
//
//  The 5 supported composition types used throughout the app:
//  camera overlay, ML classification, gallery categorisation.
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

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
