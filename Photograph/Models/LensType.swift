//
//  LensType.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation

/// Represents available camera lens options.
/// DiscoverySession dynamically determines which lenses the device supports.
enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5×"
    case wide = "1×"
    case telephoto = "2×"
    case telephoto3 = "3×"

    var id: String {
        rawValue
    }

    /// Maps to AVCaptureDevice.DeviceType for DiscoverySession lookup.
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        case .telephoto3: return .builtInTelephotoCamera
        }
    }

    /// Zoom factor relative to wide-angle (1×) baseline.
    var zoomFactor: CGFloat {
        switch self {
        case .ultraWide: return 0.5
        case .wide: return 1.0
        case .telephoto: return 2.0
        case .telephoto3: return 3.0
        }
    }
}
