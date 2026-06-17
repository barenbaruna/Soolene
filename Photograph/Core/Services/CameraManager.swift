//
//  CameraManager.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Manages the AVCaptureSession pipeline.
@Observable
final class CameraManager: NSObject, @unchecked Sendable {
    // MARK: - Observable State (always mutated on MainActor)

    var isSessionRunning = false
    var isUsingFrontCamera = false
    var isCapturingPhoto = false
    var flashMode: AVCaptureDevice.FlashMode = .off
    var exposureBias: Float = 0.0

    /// The processed preview image to show in the Review sheet
    var capturedImage: UIImage?

    /// The raw JPEG data including EXIF, already cropped to the target aspect ratio
    var capturedPhotoData: Data?

    /// User-facing capture failure message (front camera path).
    var captureError: String?

    var availableLenses: [LensType] = [.wide]
    var selectedLens: LensType = .wide

    // MARK: - Session

    let session = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "com.photograph.sessionQueue", qos: .userInitiated)
    let processingQueue = DispatchQueue(label: "com.photograph.processingQueue", qos: .userInitiated)

    // MARK: - Outputs

    let photoOutput = AVCapturePhotoOutput()
    let videoDataOutput = AVCaptureVideoDataOutput()
    let depthDataOutput = AVCaptureDepthDataOutput()
    var outputSynchronizer: AVCaptureDataOutputSynchronizer?

    /// Transient state for capture
    var pendingAspectRatio: AspectRatioMode = .fourThree

    /// Largest photo dimensions configured on `photoOutput` (mutated on `sessionQueue`).
    var configuredMaxPhotoDimensions: CMVideoDimensions?

    // MARK: - Rotation
    
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    // MARK: - Frame callback

    var onFrameCaptured: (@Sendable (CMSampleBuffer, AVDepthData?) -> Void)?
    var onPreviewFrameReady: (@Sendable () -> Void)?

    private var hasDeliveredPreviewFrame = false

    /// Discovered once per manager — shared by live zoom and handoff capture.
    let zoomCapabilities: ZoomDeviceCapabilities
    let zoomMapping = ZoomMappingEngine()

    // MARK: - Setup

    override init() {
        zoomCapabilities = ZoomDeviceCapabilities.discover()
        super.init()
        discoverAvailableLenses()
    }

    func checkPermissionsAndSetup() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await setupSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { await setupSession() }
        default:
            break
        }
    }

    private func setupSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                self.discoverAvailableLenses()
                self.configureSession(useFront: false, displayMultiplier: 1.0)
                continuation.resume()
            }
        }
        startSession()
    }

    // MARK: - Lens Discovery

    private func discoverAvailableLenses() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )

        var lenses: [LensType] = []
        let deviceTypes = Set(discoverySession.devices.map { $0.deviceType })

        // Always show ultrawide if physically present
        if deviceTypes.contains(.builtInUltraWideCamera) { lenses.append(.ultraWide) }

        // Wide (1×) is always present
        lenses.append(.wide)

        // 2× digital crop on wide — always useful on any device
        lenses.append(.twoX)

        lenses.append(.fourX)
        if deviceTypes.contains(.builtInTelephotoCamera) {
            lenses.append(.tele)
        } else {
            lenses.append(.tenX)
        }

        DispatchQueue.main.async { [weak self] in
            self?.availableLenses = lenses
        }
    }

    func configureSession(useFront: Bool, displayMultiplier: CGFloat = 1.0) {
        session.beginConfiguration()
        session.sessionPreset = useFront ? .high : .photo

        DispatchQueue.main.async { [weak self] in
            self?.isUsingFrontCamera = useFront
        }

        session.inputs.forEach { session.removeInput($0) }

        let device: AVCaptureDevice?
        if useFront {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            device = ZoomDeviceCapabilities.rearVirtualDevice()
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }

        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        session.outputs
            .compactMap { $0 as? AVCaptureVideoDataOutput }
            .forEach { session.removeOutput($0) }

        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        session.outputs
            .compactMap { $0 as? AVCaptureDepthDataOutput }
            .forEach { session.removeOutput($0) }
            
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        outputSynchronizer = nil
        if !useFront, session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = false
        }

        if !useFront, device.activeFormat.supportedDepthDataFormats.isEmpty == false {
            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
            outputSynchronizer?.setDelegate(
                self,
                queue: DispatchQueue(label: "com.photograph.videoQueue", qos: .userInitiated)
            )
        } else {
            videoDataOutput.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(label: "com.photograph.videoQueue", qos: .userInitiated)
            )
        }

        hasDeliveredPreviewFrame = false

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        configurePhotoOutput(for: device)

        if let connection = videoDataOutput.connection(with: .video) {
            connection.isVideoMirrored = useFront
        }
        
        // Setup Rotation Coordinator to automatically keep the horizon level (Landscape fix)
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            rotationObservation = rotationCoordinator?.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                
                self.sessionQueue.async {
                    // Update video output
                    if let connection = self.videoDataOutput.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                    // Update LiDAR depth output to perfectly align with RGB!
                    if let connection = self.depthDataOutput.connection(with: .depthData), connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                    // Update photo output
                    if let connection = self.photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                }
            }
        session.commitConfiguration()

        if !useFront {
            applyDisplayZoom(displayMultiplier, on: device)
        }
    }

    /// Applies display-space multiplier to the active rear virtual camera (call on `sessionQueue`).
    func applyDisplayZoom(_ displayMultiplier: CGFloat, on device: AVCaptureDevice) {
        let application = zoomMapping.map(
            displayMultiplier: displayMultiplier,
            path: .avHandoff,
            capabilities: zoomCapabilities
        )
        do {
            try device.lockForConfiguration()
            let zoom = min(
                max(application.deviceVideoZoomFactor, device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
        } catch {
            // Non-fatal — capture with current zoom.
        }
    }

    // MARK: - Start / Stop

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            let running = self.session.isRunning
            DispatchQueue.main.async { self.isSessionRunning = running }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    func stopSessionAndWait() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                    continuation.resume()
                }
            }
        }
    }

    func notifyPreviewFrameIfNeeded() {
        guard !hasDeliveredPreviewFrame else { return }
        hasDeliveredPreviewFrame = true
        onPreviewFrameReady?()
    }
}
