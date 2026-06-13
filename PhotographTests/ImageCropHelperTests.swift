//
//  ImageCropHelperTests.swift
//  PhotographTests
//

import CoreGraphics
import UIKit
import XCTest
@testable import Photograph

final class ImageCropHelperTests: XCTestCase {

    func testCenterCropToVisibleFractionReducesDimensions() throws {
        let image = makeSolidImage(width: 100, height: 200)
        let jpeg = try XCTUnwrap(image.jpegData(compressionQuality: 1.0))

        let cropped = try XCTUnwrap(
            ImageCropHelper.centerCropToVisibleFraction(imageData: jpeg, visibleFraction: 0.5)
        )
        let result = try XCTUnwrap(UIImage(data: cropped))
        let pixels = try XCTUnwrap(result.cgImage)

        XCTAssertEqual(pixels.width, 50)
        XCTAssertEqual(pixels.height, 100)
    }

    func testCenterCropNoOpAtFullFraction() throws {
        let image = makeSolidImage(width: 80, height: 80)
        let jpeg = try XCTUnwrap(image.jpegData(compressionQuality: 1.0))

        let cropped = try XCTUnwrap(
            ImageCropHelper.centerCropToVisibleFraction(imageData: jpeg, visibleFraction: 1.0)
        )

        XCTAssertEqual(cropped.count, jpeg.count)
    }

    private func makeSolidImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
