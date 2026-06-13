//
//  CoordinateMapperTests.swift
//  PhotographTests
//

import CoreGraphics
import XCTest
@testable import Photograph

final class CoordinateMapperTests: XCTestCase {

    func testNormalizedPointRoundTrip() {
        let viewSize = CGSize(width: 390, height: 844)
        let viewPoint = CGPoint(x: 120, y: 300)

        let normalized = CoordinateMapper.normalizedPoint(in: viewSize, viewPoint: viewPoint)
        let restored = CoordinateMapper.viewPoint(from: normalized, in: viewSize)

        XCTAssertEqual(restored.x, viewPoint.x, accuracy: 0.01)
        XCTAssertEqual(restored.y, viewPoint.y, accuracy: 0.01)
    }

    func testViewNormalizedToImageNormalizedCentersWideSensor() {
        let viewSize = CGSize(width: 390, height: 844)
        let imageSize = CGSize(width: 4032, height: 3024)
        let centerView = CGPoint(x: 0.5, y: 0.5)

        let imagePoint = CoordinateMapper.viewNormalizedToImageNormalized(
            viewNormalized: centerView,
            viewSize: viewSize,
            imageSize: imageSize
        )

        XCTAssertEqual(imagePoint.x, 0.5, accuracy: 0.02)
        XCTAssertGreaterThan(imagePoint.y, 0.0)
        XCTAssertLessThan(imagePoint.y, 1.0)
    }
}
