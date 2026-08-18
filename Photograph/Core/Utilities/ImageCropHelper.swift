//
//  ImageCropHelper.swift
//  Soolene
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Utility to handle image cropping while preserving EXIF metadata.
enum ImageCropHelper {
    /// Crops the given JPEG data to the specified aspect ratio.
    /// Returns the cropped JPEG data with the original metadata intact.
    static func cropImageWithMetadata(imageData: Data, ratio: AspectRatioMode) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let isRotated = {
            if let orientation = metadata[kCGImagePropertyOrientation as String] as? UInt {
                return orientation >= 5 && orientation <= 8
            }
            return false
        }()

        let cropRect = visiblePreviewCropRect(
            pixelSize: CGSize(width: width, height: height),
            aspectRatio: ratio,
            isRotated: isRotated
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }

        // Write the cropped image back with the original metadata
        CGImageDestinationAddImage(destination, croppedCGImage, metadata as CFDictionary)

        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }

        return nil
    }

    /// Center crop matching the active aspect-ratio frame shown over the full-screen aspect-fill preview.
    static func visiblePreviewCropRect(
        pixelSize: CGSize,
        aspectRatio: AspectRatioMode,
        isRotated: Bool,
        screenSize: CGSize = UIScreen.main.bounds.size
    ) -> CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }

        let displaySize = isRotated
            ? CGSize(width: pixelSize.height, height: pixelSize.width)
            : pixelSize
        let portraitScreen = CGSize(
            width: min(screenSize.width, screenSize.height),
            height: max(screenSize.width, screenSize.height)
        )
        let activeRect = aspectRatio.cropRect(in: portraitScreen)

        let scale = max(
            portraitScreen.width / displaySize.width,
            portraitScreen.height / displaySize.height
        )
        let scaledSize = CGSize(
            width: displaySize.width * scale,
            height: displaySize.height * scale
        )
        let cropOffset = CGPoint(
            x: max(0, (scaledSize.width - portraitScreen.width) / 2),
            y: max(0, (scaledSize.height - portraitScreen.height) / 2)
        )

        let visibleDisplayRect = CGRect(
            x: (activeRect.minX + cropOffset.x) / scale,
            y: (activeRect.minY + cropOffset.y) / scale,
            width: activeRect.width / scale,
            height: activeRect.height / scale
        )

        let cropWidth = isRotated ? visibleDisplayRect.height : visibleDisplayRect.width
        let cropHeight = isRotated ? visibleDisplayRect.width : visibleDisplayRect.height
        return CGRect(
            x: (pixelSize.width - cropWidth) / 2,
            y: (pixelSize.height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight
        ).integral.intersection(CGRect(origin: .zero, size: pixelSize))
    }

    /// Center-crops to the fraction of the image visible through a scaled preview (e.g. 0.5 = half width/height).
    static func centerCropToVisibleFraction(imageData: Data, visibleFraction: CGFloat) -> Data? {
        let fraction = min(max(visibleFraction, 0.1), 1.0)
        guard fraction < 0.999 else { return imageData }

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropWidth = width * fraction
        let cropHeight = height * fraction
        let cropRect = CGRect(
            x: (width - cropWidth) / 2,
            y: (height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, croppedCGImage, metadata as CFDictionary)

        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }

        return nil
    }
}
