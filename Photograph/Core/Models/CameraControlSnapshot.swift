//
//  CameraControlSnapshot.swift
//  Photograph
//
//  Camera control state synchronized across AR guidance and AV capture handoff.
//

import AVFoundation
import CoreGraphics
import Foundation

/// Point-in-time camera controls captured before AR → AV handoff.
struct CameraControlSnapshot: Equatable {
    /// User-facing zoom multiplier (ruler display).
    var displayMultiplier: CGFloat
    /// Derived lens preset for telemetry and legacy paths.
    var lens: LensType
    var flashMode: AVCaptureDevice.FlashMode
    var exposureBias: Float
    /// Normalized view-space focus point, if tap-to-focus was used.
    var focusPointNormalized: CGPoint?

    /// Legacy alias — same as `displayMultiplier`.
    var zoomFactor: CGFloat {
        get { displayMultiplier }
        set { displayMultiplier = newValue }
    }

    static func fromSpatialEngine(
        _ engine: SpatialCameraEngine,
        displayMultiplier: CGFloat
    ) -> CameraControlSnapshot {
        CameraControlSnapshot(
            displayMultiplier: displayMultiplier,
            lens: LensType.preset(
                containing: displayMultiplier,
                in: LensType.availableOnDevice
            ),
            flashMode: engine.flashMode,
            exposureBias: engine.exposureBias,
            focusPointNormalized: nil
        )
    }
}
