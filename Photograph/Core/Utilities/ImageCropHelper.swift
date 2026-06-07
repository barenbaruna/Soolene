//
//  ImageCropHelper.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Utility to handle image cropping while preserving EXIF metadata.
enum ImageCropHelper {
    /// Crops the given JPEG data to the specified aspect ratio.
    /// Returns the cropped JPEG data with the original metadata intact.
    static func cropImageWithMetadata(imageData: Data, ratio: AspectRatioMode) -> Data? {
        if ratio == .free { return imageData }

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // Calculate crop rectangle
        var cropRect = CGRect.zero
        switch ratio {
        case .oneOne:
            let side = min(width, height)
            cropRect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
        case .sixteenNine:
            // Assuming portrait orientation by default for photos
            let targetHeight = width * (16.0 / 9.0)
            if targetHeight <= height {
                cropRect = CGRect(x: 0, y: (height - targetHeight) / 2, width: width, height: targetHeight)
            } else {
                let targetWidth = height * (9.0 / 16.0)
                cropRect = CGRect(x: (width - targetWidth) / 2, y: 0, width: targetWidth, height: height)
            }
        case .fourThree:
            // Assuming portrait orientation by default for photos
            let targetHeight = width * (4.0 / 3.0)
            if targetHeight <= height {
                cropRect = CGRect(x: 0, y: (height - targetHeight) / 2, width: width, height: targetHeight)
            } else {
                let targetWidth = height * (3.0 / 4.0)
                cropRect = CGRect(x: (width - targetWidth) / 2, y: 0, width: targetWidth, height: height)
            }
        case .free:
            return imageData
        }

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
}
