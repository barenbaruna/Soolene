//
//  DeviceMatrixQA.swift
//  PhotographTests
//
//  Automated checks encoding the Option B + E-lite device QA matrix.
//  Physical-device scenarios (tracking at 0.5m, burst, relocalization) are
//  validated manually using Console filters on CaptureTelemetry.
//

import ARKit
import XCTest
@testable import Photograph

final class DeviceMatrixQATests: XCTestCase {

    func testWidePrimaryFormatAvailableOrFallbackDocumented() throws {
        guard ARWorldTrackingConfiguration.isSupported else {
            throw XCTSkip("ARKit world tracking unavailable on this host")
        }

        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        XCTAssertFalse(formats.isEmpty, "Device must expose at least one AR video format")

        let selection = ARVideoFormatSelector.selectPreferredFormat(from: formats)
        XCTAssertNotNil(selection, "Format selection must not fail")

        if formats.contains(where: { $0.captureDeviceType == .builtInWideAngleCamera }) {
            XCTAssertEqual(
                selection?.format.captureDeviceType,
                .builtInWideAngleCamera,
                "Option B must prefer wide-angle when available"
            )
        }
    }

    func testTelemetryFormatDescriptionIsStable() throws {
        guard ARWorldTrackingConfiguration.isSupported else {
            throw XCTSkip("ARKit world tracking unavailable on this host")
        }

        let format = ARWorldTrackingConfiguration.supportedVideoFormats.first
        let description = format.map(ARVideoFormatSelector.formatDescription)
        XCTAssertNotNil(description)
        XCTAssertTrue(description?.contains("fps") == true)
        XCTAssertTrue(description?.contains("hiRes=") == true)
    }

    func testCaptureArchitectureFlagsDefaultsMatchPlan() {
        XCTAssertTrue(CaptureArchitectureFlags.elLiteCaptureEnabled)
        XCTAssertTrue(CaptureArchitectureFlags.avFallbackEnabled)
        XCTAssertTrue(CaptureArchitectureFlags.telemetryEnabled)
    }
}
