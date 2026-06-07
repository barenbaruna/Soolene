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
    var flashMode: AVCaptureDevice.FlashMode = .off
    var exposureBias: Float = 0.0

    /// The processed preview image to show in the Review sheet
    var capturedImage: UIImage?

    /// The raw JPEG data including EXIF, already cropped to the target aspect ratio
    var capturedPhotoData: Data?

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
    var pendingAspectRatio: AspectRatioMode = .free

    // MARK: - Rotation
    
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    // MARK: - Frame callback

    var onFrameCaptured: (@Sendable (CMSampleBuffer, AVDepthData?) -> Void)?

    // MARK: - Setup

    override init() {
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
                self.configureSession(useFront: false, lens: .wide)
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

        // 5× telephoto (iPhone 15 Pro Max, 16 Pro, 17 Pro)
        if deviceTypes.contains(.builtInTelephotoCamera) { lenses.append(.fiveX) }

        DispatchQueue.main.async { [weak self] in
            self?.availableLenses = lenses
        }
    }

    func configureSession(useFront: Bool, lens: LensType = .wide) {
        session.beginConfiguration()
        session.sessionPreset = .photo // Highest quality for photo

        session.inputs.forEach { session.removeInput($0) }

        let device: AVCaptureDevice?
        if useFront {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            // Check for LiDAR camera first for 3D depth, then fallback to requested lens/wide angle
            if let lidarDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) {
                device = lidarDevice
            } else {
                device = AVCaptureDevice.default(lens.deviceType, for: .video, position: .back)
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            }
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

        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = false // Raw depth for precise alignment
        }

        // Setup Synchronizer if depth is supported by this device format
        if device.activeFormat.supportedDepthDataFormats.isEmpty == false {
            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
            outputSynchronizer?.setDelegate(
                self,
                queue: DispatchQueue(label: "com.photograph.videoQueue", qos: .userInitiated)
            )
        } else {
            // Fallback for non-LiDAR/non-depth devices
            outputSynchronizer = nil
            videoDataOutput.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(label: "com.photograph.videoQueue", qos: .userInitiated)
            )
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        photoOutput.maxPhotoQualityPrioritization = .quality

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

        // Apply digital zoom for lenses that use it (e.g. 2× crop on wide-angle)
        if !useFront, lens.zoomFactor > 1.0 {
            if let device = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device,
               let _ = try? device.lockForConfiguration()
            {
                device.videoZoomFactor = min(lens.zoomFactor, device.maxAvailableVideoZoomFactor)
                device.unlockForConfiguration()
            }
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
}
