//
//  SceneGeometry.swift
//  Soolene
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
    /// Typically derived from Attention-Based Saliency, heavily smoothed via EMA.
    var saliencyCentroid: CGPoint? = nil

    /// Normalized centroid of the objectness-based saliency region (foreground object detection).
    /// Used as a fallback or in tandem with attention saliency for non-human subjects.
    var objectnessCentroid: CGPoint? = nil

    /// Bounding rect of all salient objects combined (UIKit coords).
    var saliencyBounds: CGRect? = nil

    /// Fraction of frame area occupied by salient objects (0.0–1.0).
    var saliencyAreaRatio: CGFloat = 0

    // MARK: - Horizon

    /// Horizon angle in degrees. 0 = perfectly level; positive = clockwise tilt.
    var horizonAngle: Double = 0.0

    /// True when the latest Vision horizon request returned a valid observation.
    var horizonDetected: Bool = false

    /// Device roll from CoreMotion (degrees), used as horizontal fallback when Vision has no horizon.
    var deviceRollDegrees: Double? = nil

    // MARK: - Faces

    /// Normalized CGRects of all detected faces (UIKit coords).
    var faceRects: [CGRect] = []

    // MARK: - Body Pose

    /// Approximate center of mass of a detected human body (UIKit coords).
    /// Calculated from shoulder and hip keypoints via VNDetectHumanBodyPoseRequest.
    /// Priority: face centroid > bodyCenter > saliencyCentroid
    var bodyCenter: CGPoint? = nil

    // MARK: - Structural Lines

    /// True when VNDetectRectanglesRequest found tall/narrow vertical shapes
    /// (e.g., columns, trees, buildings). Used for Vertical composition detection.
    var hasStrongVerticals: Bool = false

    // MARK: - Subject Lock (separated intent vs tracking)

    /// Immutable user long-press location until lock is cleared. Normalised UIKit coords (0–1).
    var userLockOrigin: CGPoint? = nil

    /// Live tracked subject position (AR projection or Vision tracker). Normalised UIKit coords.
    var trackedSubjectPoint: CGPoint? = nil

    /// Offset from raw anchor/bbox projection to `userLockOrigin`, frozen on first track frame.
    var subjectTrackingOffset: CGVector? = nil

    /// True when the user has locked a subject.
    var isSubjectLocked: Bool { userLockOrigin != nil }

    // MARK: - Locked State

    /// The final, smoothed position of the subject after passing through the 1-Euro filter.
    /// Drives the Bracket UI smoothly.
    var smoothedSubjectPoint: CGPoint? = nil

    /// A stable target position calculated for the current composition and subject.
    /// Locks the target in place to prevent jitter and ambiguity as the subject moves.
    /// Should be cleared when the composition type changes or the user explicitly retaps.
    var lockedTargetPoint: CGPoint? = nil

    // MARK: - Subject Lock Lifecycle

    mutating func establishUserLock(at point: CGPoint) {
        userLockOrigin = point
        trackedSubjectPoint = point
        subjectTrackingOffset = nil
        smoothedSubjectPoint = nil
    }

    mutating func clearUserLock() {
        userLockOrigin = nil
        trackedSubjectPoint = nil
        subjectTrackingOffset = nil
        smoothedSubjectPoint = nil
    }

    /// Applies tap-relative tracking: preserves the user's chosen pixel relative to the raw projection.
    mutating func applyTrackedProjection(_ rawProjection: CGPoint) {
        guard let origin = userLockOrigin else { return }
        let result = SubjectLockMath.trackedPoint(
            rawProjection: rawProjection,
            userLockOrigin: origin,
            existingOffset: subjectTrackingOffset
        )
        subjectTrackingOffset = result.offset
        trackedSubjectPoint = result.point
    }
}
