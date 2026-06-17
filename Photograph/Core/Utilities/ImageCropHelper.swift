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
        
        let isRotated = {
            if let orientation = metadata[kCGImagePropertyOrientation as String] as? UInt {
                return orientation >= 5 && orientation <= 8
            }
            return false
        }()
        
        let effectiveRatio = ratio.pixelSpaceRatio(isRotated: isRotated)
        
        switch ratio {
        case .oneOne:
            let side = min(width, height)
            cropRect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
        case .sixteenNine, .fourThree:
            if let targetRatioStruct = effectiveRatio {
                let targetRatio = targetRatioStruct.w / targetRatioStruct.h
                let currentRatio = width / height
                
                if targetRatio < currentRatio {
                    let targetWidth = height * targetRatio
                    cropRect = CGRect(x: (width - targetWidth) / 2, y: 0, width: targetWidth, height: height)
                } else {
                    let targetHeight = width / targetRatio
                    cropRect = CGRect(x: 0, y: (height - targetHeight) / 2, width: width, height: targetHeight)
                }
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
