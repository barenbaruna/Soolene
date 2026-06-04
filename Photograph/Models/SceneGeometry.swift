//
//  SceneGeometry.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 25/05/26.
//

import CoreGraphics
import Foundation

/// Real-time geometric data from Vision APIs.
/// Used by GuidanceEngine to validate ML predictions.
struct SceneGeometry: Equatable {
    // MARK: - Saliency

    /// Normalized centroid of the salient region (UIKit coords: origin top-left).
    var saliencyCentroid: CGPoint? = nil

    /// Bounding rect of all salient objects combined (UIKit coords).
    var saliencyBounds: CGRect? = nil

    /// Fraction of frame area occupied by salient objects (0.0–1.0).
    var saliencyAreaRatio: CGFloat = 0

    // MARK: - Horizon

    /// Horizon angle in degrees. 0 = perfectly level; positive = clockwise tilt.
    var horizonAngle: Double = 0.0

    // MARK: - Faces

    /// Normalized CGRect of the first detected face (UIKit coords).
    var faceRect: CGRect? = nil

    // MARK: - Structural Lines

    /// True when VNDetectRectanglesRequest found tall/narrow vertical shapes
    /// (e.g., columns, trees, buildings). Used for Vertical composition detection.
    var hasStrongVerticals: Bool = false
}
