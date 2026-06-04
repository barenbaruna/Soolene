//
//  LensType.swift
//  Photograph
//
//  Represents available camera lenses.
//  DiscoverySession dynamically picks which ones the device supports.
//  iPhone Pro models: 0.5× (ultrawide), 1× (wide), 2× (tele crop), 5× (tele), 8× (max digital)
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation

/// All possible lens focal lengths supported by the app.
/// Actual availability is determined at runtime via `AVCaptureDevice.DiscoverySession`.
enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5×"
    case wide = "1×"
    case twoX = "2×"
    case fiveX = "5×"

    var id: String {
        rawValue
    }

    /// The physical camera device type this lens maps to.
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .twoX: return .builtInWideAngleCamera // 2× is a 2× digital crop on wide
        case .fiveX: return .builtInTelephotoCamera
        }
    }

    /// Zoom factor applied on the selected device (relative to its 1× baseline).
    var zoomFactor: CGFloat {
        switch self {
        case .ultraWide: return 1.0 // ultrawide device native
        case .wide: return 1.0
        case .twoX: return 2.0 // digital 2× crop on wide-angle
        case .fiveX: return 1.0 // telephoto device native (5× equivalent)
        }
    }
}
