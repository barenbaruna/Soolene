//
//  LensType.swift
//  Photograph
//
//  Represents available camera lenses.
//  DiscoverySession dynamically picks which ones the device supports.
//
//  iPhone basic series:    0.5×, 1×, 2×
//  iPhone Pro/Max series:  0.5×, 1×, 2×, 5× (optical telephoto)
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation

/// All possible lens focal lengths supported by the app.
/// Actual availability is determined at runtime via `AVCaptureDevice.DiscoverySession`.
enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5×"
    case wide      = "1×"
    case twoX      = "2×"
    case fiveX     = "5×"

    var id: String { rawValue }

    /// The physical camera device type this lens maps to.
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide:      return .builtInWideAngleCamera
        case .twoX:      return .builtInWideAngleCamera   // 2× digital crop
        case .fiveX:     return .builtInTelephotoCamera
        }
    }

    /// Zoom factor applied on the selected device.
    var zoomFactor: CGFloat {
        switch self {
        case .ultraWide: return 1.0
        case .wide:      return 1.0
        case .twoX:      return 2.0
        case .fiveX:     return 1.0  // telephoto device native
        }
    }

    // MARK: - Device-Aware Lens List

    /// Returns the lenses available on the current device.
    /// Basic iPhones: 0.5×, 1×, 2×
    /// Pro/Max iPhones: 0.5×, 1×, 2×, 5×
    static var availableOnDevice: [LensType] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        let deviceTypes = Set(discovery.devices.map { $0.deviceType })

        var lenses: [LensType] = []

        if deviceTypes.contains(.builtInUltraWideCamera) {
            lenses.append(.ultraWide)
        }
        if deviceTypes.contains(.builtInWideAngleCamera) {
            lenses.append(.wide)
            lenses.append(.twoX) // 2× is always available via digital crop on wide
        }
        if deviceTypes.contains(.builtInTelephotoCamera) {
            lenses.append(.fiveX)
        }

        return lenses.isEmpty ? [.wide] : lenses
    }

    /// Nearest preset lens for the current zoom factor (toolbar display).
    static func closest(toZoom zoom: CGFloat) -> LensType {
        let candidates: [LensType] = [.ultraWide, .wide, .twoX, .fiveX]
        return candidates.min(by: { abs($0.zoomFactor - zoom) < abs($1.zoomFactor - zoom) }) ?? .wide
    }
}
