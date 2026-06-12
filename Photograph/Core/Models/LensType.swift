//
//  LensType.swift
//  Photograph
//
//  Internal zoom preset identifiers — telemetry and handoff legacy only (no UI chips).
//

import AVFoundation

/// Discrete zoom presets for telemetry — not shown in UI (continuous ruler is primary).
enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5×"
    case wide      = "1×"
    case twoX      = "2×"
    case fourX     = "4×"
    case tele      = "tele"
    case tenX      = "10×"

    var id: String { displayLabel }

    /// User-visible label derived from device capabilities.
    var displayLabel: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide:      return "1×"
        case .twoX:      return "2×"
        case .fourX:     return "4×"
        case .tele:
            if let tele = ZoomDeviceCapabilities.discover().teleDisplayMultiplier {
                return String(format: "%.0f×", tele)
            }
            return "5×"
        case .tenX:      return "10×"
        }
    }

    var nominalMultiplier: CGFloat {
        switch self {
        case .ultraWide: return 0.5
        case .wide:      return 1.0
        case .twoX:      return 2.0
        case .fourX:     return 4.0
        case .tele:
            return ZoomDeviceCapabilities.discover().teleDisplayMultiplier ?? 5.0
        case .tenX:      return 10.0
        }
    }

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide, .twoX, .fourX, .tenX: return .builtInWideAngleCamera
        case .tele:      return .builtInTelephotoCamera
        }
    }

    var avDigitalZoomFactor: CGFloat {
        switch self {
        case .ultraWide, .wide, .tele: return 1.0
        case .twoX:      return 2.0
        case .fourX:     return 4.0
        case .tenX:      return 10.0
        }
    }

    // MARK: - Device-aware presets

    static var availableOnDevice: [LensType] {
        let caps = ZoomDeviceCapabilities.discover()
        var lenses: [LensType] = []
        if caps.hasUltraWide { lenses.append(.ultraWide) }
        lenses.append(.wide)
        lenses.append(.twoX)
        lenses.append(.fourX)
        if caps.hasTelephoto {
            lenses.append(.tele)
        } else {
            lenses.append(.tenX)
        }
        return lenses.isEmpty ? [.wide] : lenses
    }

    /// Preset whose band contains the current display multiplier (telemetry).
    static func preset(containing multiplier: CGFloat, in available: [LensType]) -> LensType {
        let boundaries = ZoomDeviceCapabilities.discover().majorBoundaries
        let sortedBoundaries = boundaries.sorted()
        var activeBoundary: CGFloat = sortedBoundaries.first ?? 1.0
        for boundary in sortedBoundaries where multiplier >= boundary - 0.05 {
            activeBoundary = boundary
        }

        switch activeBoundary {
        case ..<0.75: return available.contains(.ultraWide) ? .ultraWide : .wide
        case ..<1.5: return .wide
        case ..<3.0: return .twoX
        case ..<4.5: return .fourX
        default:
            if available.contains(.tele) { return .tele }
            return .tenX
        }
    }
}
