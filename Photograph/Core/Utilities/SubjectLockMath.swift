//
//  SubjectLockMath.swift
//  Soolene
//
//  Pure functions for subject-lock coordinate math (unit-testable).
//

import CoreGraphics

enum SubjectLockMath {

    /// Applies a frozen offset so the tracked point preserves the user's tap location.
    static func trackedPoint(
        rawProjection: CGPoint,
        userLockOrigin: CGPoint,
        existingOffset: CGVector?
    ) -> (point: CGPoint, offset: CGVector) {
        let offset = existingOffset ?? CGVector(
            dx: userLockOrigin.x - rawProjection.x,
            dy: userLockOrigin.y - rawProjection.y
        )
        let point = CGPoint(
            x: rawProjection.x + offset.dx,
            y: rawProjection.y + offset.dy
        )
        return (point, offset)
    }

    /// Applies a frozen offset for Vision bbox-center tracking.
    static func trackedPoint(
        boundingBoxCenter: CGPoint,
        userLockOrigin: CGPoint,
        existingOffset: CGVector?
    ) -> (point: CGPoint, offset: CGVector) {
        trackedPoint(
            rawProjection: boundingBoxCenter,
            userLockOrigin: userLockOrigin,
            existingOffset: existingOffset
        )
    }
}
