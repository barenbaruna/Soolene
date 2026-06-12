//
//  ClassicCameraProviding.swift
//  Photograph
//

import AVFoundation
import UIKit

/// AVFoundation camera pipeline (front camera and B2 fallback).
@MainActor
protocol ClassicCameraProviding: AnyObject {
    var isSessionRunning: Bool { get }
    var isCapturingPhoto: Bool { get }
    var flashMode: AVCaptureDevice.FlashMode { get set }
    var exposureBias: Float { get set }
    var capturedPhotoData: Data? { get }
    var captureError: String? { get set }
    var availableLenses: [LensType] { get }
    var selectedLens: LensType { get set }

    func configureSession(useFront: Bool, lens: LensType)
    func startSession()
    func stopSession()
    func stopSessionAndWait() async
    func capturePhoto(aspectRatio: AspectRatioMode)
    func setExposureBias(_ bias: Float)
    func setZoomFactor(_ factor: CGFloat)
    func cycleFlash()
}
