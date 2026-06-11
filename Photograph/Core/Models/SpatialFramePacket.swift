//
//  SpatialFramePacket.swift
//  Photograph
//
//  Immutable frame payload safe to pass off the ARSession delegate thread.
//

import CoreGraphics
import CoreVideo
import UIKit

/// Vision-safe snapshot extracted synchronously inside the ARSession delegate.
struct SpatialFramePacket: @unchecked Sendable {
    /// Copied camera buffer for Vision; nil when Vision is still processing the prior frame.
    let pixelBuffer: CVPixelBuffer?
    let spatialSubjectPoint: CGPoint?
    let viewportSize: CGSize
    let interfaceOrientation: UIInterfaceOrientation
}
