//
//  SubjectLockAccuracyTests.swift
//  PhotographTests
//

import CoreGraphics
import XCTest
@testable import Photograph

final class SubjectLockAccuracyTests: XCTestCase {

    func testTrackedPointPreservesUserTapOnFirstProjection() {
        let userTap = CGPoint(x: 0.52, y: 0.28)
        let rawAnchorProjection = CGPoint(x: 0.52, y: 0.42)

        let result = SubjectLockMath.trackedPoint(
            rawProjection: rawAnchorProjection,
            userLockOrigin: userTap,
            existingOffset: nil
        )

        XCTAssertEqual(result.point.x, userTap.x, accuracy: 0.0001)
        XCTAssertEqual(result.point.y, userTap.y, accuracy: 0.0001)
        XCTAssertEqual(Double(result.offset.dx), Double(userTap.x - rawAnchorProjection.x), accuracy: 0.0001)
        XCTAssertEqual(Double(result.offset.dy), Double(userTap.y - rawAnchorProjection.y), accuracy: 0.0001)
    }

    func testTrackedPointReusesFrozenOffset() {
        let userTap = CGPoint(x: 0.4, y: 0.3)
        let frozenOffset = CGVector(dx: 0.05, dy: -0.08)
        let rawProjection = CGPoint(x: 0.41, y: 0.39)

        let result = SubjectLockMath.trackedPoint(
            rawProjection: rawProjection,
            userLockOrigin: userTap,
            existingOffset: frozenOffset
        )

        XCTAssertEqual(result.offset.dx, frozenOffset.dx, accuracy: 0.0001)
        XCTAssertEqual(result.offset.dy, frozenOffset.dy, accuracy: 0.0001)
        XCTAssertEqual(result.point.x, rawProjection.x + frozenOffset.dx, accuracy: 0.0001)
        XCTAssertEqual(result.point.y, rawProjection.y + frozenOffset.dy, accuracy: 0.0001)
    }

    func testSceneGeometryApplyTrackedProjectionPreservesOrigin() {
        var geometry = SceneGeometry()
        geometry.establishUserLock(at: CGPoint(x: 0.6, y: 0.25))

        geometry.applyTrackedProjection(CGPoint(x: 0.6, y: 0.38))
        XCTAssertEqual(geometry.userLockOrigin?.y ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(geometry.trackedSubjectPoint?.y ?? 0, 0.25, accuracy: 0.0001)

        geometry.applyTrackedProjection(CGPoint(x: 0.62, y: 0.40))
        XCTAssertEqual(geometry.userLockOrigin?.y ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(geometry.trackedSubjectPoint?.x ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(geometry.trackedSubjectPoint?.y ?? 0, 0.27, accuracy: 0.0001)
    }

    func testResolveSubjectPointPrefersTrackedWhenLocked() {
        var geometry = SceneGeometry()
        geometry.establishUserLock(at: CGPoint(x: 0.2, y: 0.3))
        geometry.trackedSubjectPoint = CGPoint(x: 0.22, y: 0.31)
        geometry.saliencyCentroid = CGPoint(x: 0.8, y: 0.8)

        let resolved = AlignmentAnalyzer.resolveSubjectPoint(from: geometry)

        XCTAssertEqual(resolved?.x ?? 0, 0.22, accuracy: 0.0001)
        XCTAssertEqual(resolved?.y ?? 0, 0.31, accuracy: 0.0001)
    }

    func testResolveSubjectPointFallsBackToOriginWhenTrackMissing() {
        var geometry = SceneGeometry()
        geometry.establishUserLock(at: CGPoint(x: 0.33, y: 0.44))
        geometry.trackedSubjectPoint = nil

        let resolved = AlignmentAnalyzer.resolveSubjectPoint(from: geometry)

        XCTAssertEqual(resolved?.x ?? 0, 0.33, accuracy: 0.0001)
        XCTAssertEqual(resolved?.y ?? 0, 0.44, accuracy: 0.0001)
    }
}
