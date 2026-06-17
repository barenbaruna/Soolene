//
//  AspectRatioMode.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import CoreGraphics
import Foundation

/// Aspect ratio options for the viewfinder crop mask.
/// The camera always captures at the sensor's native ratio (4:3 on iPhone).
/// The crop mask is applied visually during preview and on export.
enum AspectRatioMode: String, CaseIterable, Identifiable {
    case free = "Free"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case oneOne = "1:1"

    var id: String {
        rawValue
    }

    var symbolName: String {
        switch self {
        case .free: return "rectangle.dashed"
        case .fourThree: return "rectangle"
        case .sixteenNine: return "rectangle.expand.vertical"
        case .oneOne: return "square"
        }
    }

    /// The CGFloat ratio (width / height). Returns nil for free mode (no crop).
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .fourThree: return 3.0 / 4.0 // Portrait orientation
        case .sixteenNine: return 9.0 / 16.0 // Portrait orientation
        case .oneOne: return 1.0
        }
    }

    /// Computes the visible rect within a given frame size, centered.
    func cropRect(in size: CGSize) -> CGRect {
        guard let ratio else { return CGRect(origin: .zero, size: size) }

        let frameRatio = size.width / size.height
        let cropWidth: CGFloat
        let cropHeight: CGFloat

        if ratio < frameRatio {
            // Letterbox: height fills, width shrinks
            cropHeight = size.height
            cropWidth = size.height * ratio
        } else {
            // Pillarbox: width fills, height shrinks
            cropWidth = size.width
            cropHeight = size.width / ratio
        }

        let x = (size.width - cropWidth) / 2
        let y = (size.height - cropHeight) / 2
        return CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
    }

    /// Returns the aspect ratio to apply in pixel-space CGImage coordinates,
    /// accounting for EXIF rotation where pixel width = display height.
    func pixelSpaceRatio(isRotated: Bool) -> (w: CGFloat, h: CGFloat)? {
        switch self {
        case .free: return nil
        case .oneOne: return (1, 1)
        case .sixteenNine:
            // Portrait display = 9:16 (w:h). In rotated pixel space, swap to 16:9
            return isRotated ? (16, 9) : (9, 16)
        case .fourThree:
            // Portrait display = 3:4 (w:h). In rotated pixel space, swap to 4:3
            return isRotated ? (4, 3) : (3, 4)
        }
    }
}
