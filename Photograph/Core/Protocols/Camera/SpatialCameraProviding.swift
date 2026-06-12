//
//  SpatialCameraProviding.swift
//  Photograph
//

import ARKit
import AVFoundation
import UIKit

/// Rear-camera ARKit session: preview, tracking, subject lock, and spatial capture.
@MainActor
protocol SpatialCameraProviding: AnyObject {
    var isSessionRunning: Bool { get }
    var isARKitSupported: Bool { get }
    var trackingState: ARCamera.TrackingState { get }
    var trackingStabilityProgress: Float { get }
    var flashMode: AVCaptureDevice.FlashMode { get set }
    var exposureBias: Float { get set }
    var capturedPhotoData: Data? { get }
    var captureError: String? { get set }
    var isCapturingHighResolution: Bool { get }

    func startSession()
    func stopSession()
    func stopSessionAndWait() async
    func captureHighResolutionPhoto(aspectRatio: AspectRatioMode) async
    func lockSubject(at normalizedPoint: CGPoint)
    func clearSubjectAnchor()
    func focusAndExpose(at normalizedPoint: CGPoint)
    func setExposureBias(_ bias: Float)
    func setZoomFactor(_ factor: CGFloat)
    func cycleFlash()

    func makeHandoffSnapshot(aspectRatio: AspectRatioMode) async -> CaptureHandoffSnapshot
    func pauseForHandoff() async
    func resumeAfterHandoff(_ snapshot: CaptureHandoffSnapshot, trackingTimeout: TimeInterval) async -> CaptureHandoffResumeResult
    func clearHandoffFrozenPreview()
}
