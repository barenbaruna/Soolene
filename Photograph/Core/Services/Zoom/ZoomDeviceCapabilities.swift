//
//  ZoomDeviceCapabilities.swift
//  Soolene
//
//  Runtime discovery of rear zoom range, switch factors, and tick boundaries.
//

import AVFoundation
import OSLog

/// Device-specific zoom limits discovered from AVFoundation virtual cameras.
struct ZoomDeviceCapabilities: Equatable, Sendable {
    let minDisplayZoom: CGFloat
    let maxDisplayZoom: CGFloat
    let arMaxDisplayZoom: CGFloat
    let majorBoundaries: [CGFloat]
    let hasUltraWide: Bool
    let hasTelephoto: Bool
    let teleDisplayMultiplier: CGFloat?
    let usesVirtualDevice: Bool
    let switchOverFactors: [CGFloat]

    static let fallback = ZoomDeviceCapabilities(
        minDisplayZoom: 1.0,
        maxDisplayZoom: 5.0,
        arMaxDisplayZoom: 5.0,
        majorBoundaries: [1.0, 2.0],
        hasUltraWide: false,
        hasTelephoto: false,
        teleDisplayMultiplier: nil,
        usesVirtualDevice: false,
        switchOverFactors: []
    )

    var displayRange: ClosedRange<CGFloat> {
        minDisplayZoom...maxDisplayZoom
    }

    // MARK: - Discovery

    private static let log = Logger(
        subsystem: "com.barenbaruna.Soolene",
        category: "ZoomDiscovery"
    )

    /// Queries rear virtual / constituent cameras and logs switch factors (Phase 0).
    static func discover() -> ZoomDeviceCapabilities {
        let virtual = rearVirtualDevice()
        let telePresent = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) != nil

        guard let device = virtual else {
            log.warning("zoom_discovery: no rear device — using fallback range")
            return .fallback
        }

        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0) }
        let hasUW = minZoom < 0.99
            || device.deviceType == .builtInDualWideCamera
            || device.deviceType == .builtInTripleCamera
            || AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
        let displayMax = displayMaxZoom(device: device, hasTele: telePresent, maxDeviceZoom: maxZoom)
        let teleDisplay = teleDisplayMultiplier(switchFactors: switchFactors, hasTele: telePresent)
        let boundaries = buildMajorBoundaries(
            minZoom: minZoom,
            hasUltraWide: hasUW,
            teleDisplay: teleDisplay
        )
        
        // Remove artificial AR caps: match native capability
        let arCap = displayMax

        let caps = ZoomDeviceCapabilities(
            minDisplayZoom: hasUW ? 0.5 : 1.0,
            maxDisplayZoom: displayMax,
            arMaxDisplayZoom: arCap,
            majorBoundaries: boundaries,
            hasUltraWide: hasUW,
            hasTelephoto: telePresent,
            teleDisplayMultiplier: teleDisplay,
            usesVirtualDevice: device.deviceType == .builtInTripleCamera
                || device.deviceType == .builtInDualWideCamera,
            switchOverFactors: switchFactors
        )

        log.info(
            """
            zoom_discovery device=\(device.localizedName) \
            type=\(device.deviceType.rawValue) \
            min=\(minZoom) max=\(maxZoom) \
            switchFactors=\(switchFactors) \
            displayRange=\(caps.minDisplayZoom)-\(caps.maxDisplayZoom) \
            boundaries=\(boundaries)
            """
        )

        return caps
    }

    // MARK: - Helpers

    static func rearVirtualDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private static func displayMaxZoom(
        device: AVCaptureDevice,
        hasTele: Bool,
        maxDeviceZoom: CGFloat
    ) -> CGFloat {
        if hasTele {
            // Match system Camera: 25× on 5× tele Pro, 15× on 3× tele Pro.
            if let tele = teleDisplayMultiplier(
                switchFactors: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0) },
                hasTele: true
            ), tele >= 4.5 {
                return min(maxDeviceZoom, 25.0)
            }
            return min(maxDeviceZoom, 15.0)
        }
        return min(maxDeviceZoom, 10.0)
    }

    private static func teleDisplayMultiplier(
        switchFactors: [CGFloat],
        hasTele: Bool
    ) -> CGFloat? {
        guard hasTele else { return nil }
        let teleCandidates = switchFactors.filter { $0 >= 2.5 }
        if let largest = teleCandidates.max() {
            let rounded = round(largest)
            return rounded >= 3 ? rounded : 3.0
        }
        return 5.0
    }

    private static func buildMajorBoundaries(
        minZoom: CGFloat,
        hasUltraWide: Bool,
        teleDisplay: CGFloat?
    ) -> [CGFloat] {
        var boundaries: [CGFloat] = []
        if hasUltraWide || minZoom < 0.99 {
            boundaries.append(0.5)
        }
        boundaries.append(1.0)
        boundaries.append(2.0)
        if let teleDisplay {
            boundaries.append(teleDisplay)
        }
        return Array(Set(boundaries)).sorted()
    }
}
