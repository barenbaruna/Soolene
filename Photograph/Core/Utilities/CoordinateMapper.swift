//
//  CoordinateMapper.swift
//  Photograph
//
//  Single source of truth for screen ↔ normalized UIKit coordinate conversion.
//

import ARKit
import CoreGraphics
import UIKit

enum CoordinateMapper {

    /// Converts a view-space point to normalized UIKit coordinates (0–1, origin top-left).
    static func normalizedPoint(in viewSize: CGSize, viewPoint: CGPoint) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        return CGPoint(
            x: viewPoint.x / viewSize.width,
            y: viewPoint.y / viewSize.height
        )
    }

    /// Converts normalized UIKit coordinates to view-space pixels.
    static func viewPoint(from normalized: CGPoint, in viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: normalized.x * viewSize.width,
            y: normalized.y * viewSize.height
        )
    }

    /// Projects a world-space anchor position into normalized UIKit coordinates.
    static func projectAnchor(
        _ anchor: ARAnchor,
        frame: ARFrame,
        viewportSize: CGSize,
        interfaceOrientation: UIInterfaceOrientation = .portrait
    ) -> CGPoint? {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return nil }

        let worldPosition = simd_float3(
            anchor.transform.columns.3.x,
            anchor.transform.columns.3.y,
            anchor.transform.columns.3.z
        )

        let projected = frame.camera.projectPoint(
            worldPosition,
            orientation: interfaceOrientation,
            viewportSize: viewportSize
        )

        return normalizedPoint(
            in: viewportSize,
            viewPoint: CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        )
    }

    /// UIImage orientation from ARKit EXIF orientation value.
    static func imageOrientation(fromExifOrientation exif: Int32) -> UIImage.Orientation {
        switch CGImagePropertyOrientation(rawValue: UInt32(exif)) {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        default: return .right
        }
    }

    /// Vision handler orientation for the primary back camera in portrait.
    static func visionOrientation(isFrontCamera: Bool) -> CGImagePropertyOrientation {
        isFrontCamera ? .leftMirrored : .right
    }

    /// Maps view-normalized coordinates (aspect-fill preview) to camera-image-normalized (0–1, top-left).
    static func viewNormalizedToImageNormalized(
        viewNormalized: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize
    ) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0
        else { return viewNormalized }

        let viewAspect = viewSize.width / viewSize.height
        let imageAspect = imageSize.width / imageSize.height

        let scale: CGFloat
        let cropX: CGFloat
        let cropY: CGFloat

        if imageAspect > viewAspect {
            scale = viewSize.height / imageSize.height
            let scaledWidth = imageSize.width * scale
            cropX = (scaledWidth - viewSize.width) / 2
            cropY = 0
        } else {
            scale = viewSize.width / imageSize.width
            let scaledHeight = imageSize.height * scale
            cropX = 0
            cropY = (scaledHeight - viewSize.height) / 2
        }

        let viewPx = CGPoint(x: viewNormalized.x * viewSize.width, y: viewNormalized.y * viewSize.height)
        let imagePx = CGPoint(x: (viewPx.x + cropX) / scale, y: (viewPx.y + cropY) / scale)

        return CGPoint(
            x: min(max(imagePx.x / imageSize.width, 0), 1),
            y: min(max(imagePx.y / imageSize.height, 0), 1)
        )
    }
}
