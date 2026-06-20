//
//  CaptureHandoffSnapshot.swift
//  Soolene
//
//  AR state bundle captured before pausing ARKit for AVFoundation photo capture.
//

import ARKit
import simd
import UIKit

/// Result of resuming AR after an AV handoff.
enum CaptureHandoffResumeResult: Equatable {
    case recoveredWithWorldMap
    case recoveredWithoutWorldMap
    case recoveryDeferred
    case trackingDegraded
}

/// Serializable AR + camera state for session handoff (world map is one-shot, not persisted on config).
struct CaptureHandoffSnapshot {
    var worldMap: ARWorldMap?
    var subjectAnchorTransform: simd_float4x4?
    var cameraControls: CameraControlSnapshot
    var aspectRatio: AspectRatioMode
    var frozenPreviewImage: UIImage?

    static func empty(aspectRatio: AspectRatioMode) -> CaptureHandoffSnapshot {
        CaptureHandoffSnapshot(
            worldMap: nil,
            subjectAnchorTransform: nil,
            cameraControls: CameraControlSnapshot(
                displayMultiplier: 1,
                lens: .wide,
                flashMode: .off,
                exposureBias: 0,
                focusPointNormalized: nil
            ),
            aspectRatio: aspectRatio,
            frozenPreviewImage: nil
        )
    }
}
