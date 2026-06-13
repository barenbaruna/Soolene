//
//  CaptureZoomRoutingTests.swift
//  PhotographTests
//

import XCTest
@testable import Photograph

final class CaptureZoomRoutingTests: XCTestCase {

    func testBaselineZoomAcceptsSoftSnapTolerance() {
        XCTAssertTrue(CaptureZoomRouting.isBaselineZoom(1.0))
        XCTAssertTrue(CaptureZoomRouting.isBaselineZoom(1.04))
        XCTAssertTrue(CaptureZoomRouting.isBaselineZoom(0.96))
        XCTAssertFalse(CaptureZoomRouting.isBaselineZoom(1.06))
        XCTAssertFalse(CaptureZoomRouting.isBaselineZoom(2.0))
    }

    func testELiteRoutesZoomedCaptureToAV() {
        XCTAssertFalse(
            CaptureZoomRouting.shouldUseZoomedAVHandoff(
                displayMultiplier: 1.0,
                elLiteEnabled: true
            )
        )
        XCTAssertTrue(
            CaptureZoomRouting.shouldUseZoomedAVHandoff(
                displayMultiplier: 2.0,
                elLiteEnabled: true
            )
        )
        XCTAssertFalse(
            CaptureZoomRouting.shouldUseZoomedAVHandoff(
                displayMultiplier: 2.0,
                elLiteEnabled: false
            )
        )
    }

    func testEffectivePreviewScaleClampsSubOneZoom() {
        XCTAssertEqual(CaptureZoomRouting.effectivePreviewScale(for: 0.5), 1.0)
        XCTAssertEqual(CaptureZoomRouting.effectivePreviewScale(for: 1.0), 1.0)
        XCTAssertEqual(CaptureZoomRouting.effectivePreviewScale(for: 2.0), 2.0)
    }
}
