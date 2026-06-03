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
    private let sessionQueue = DispatchQueue(label: "com.photograph.sessionQueue", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.photograph.processingQueue", qos: .userInitiated)

    // MARK: - Outputs

    private let photoOutput = AVCapturePhotoOutput()
    let videoDataOutput = AVCaptureVideoDataOutput()

    /// Transient state for capture
    private var pendingAspectRatio: AspectRatioMode = .free

    // MARK: - Frame callback

    var onFrameCaptured: (@Sendable (CMSampleBuffer) -> Void)?

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

    private func configureSession(useFront: Bool, lens: LensType = .wide) {
        session.beginConfiguration()
        session.sessionPreset = .photo // Highest quality for photo

        session.inputs.forEach { session.removeInput($0) }

        let device: AVCaptureDevice?
        if useFront {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            device = AVCaptureDevice.default(lens.deviceType, for: .video, position: .back)
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
        videoDataOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "com.photograph.videoQueue", qos: .userInitiated)
        )
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        photoOutput.maxPhotoQualityPrioritization = .quality

        if let connection = videoDataOutput.connection(with: .video) {
            connection.isVideoMirrored = useFront
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()

        // Apply digital zoom for lenses that use it (e.g. 2× crop on wide-angle)
        if !useFront && lens.zoomFactor > 1.0 {
            if let device = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device,
               let _ = try? device.lockForConfiguration() {
                device.videoZoomFactor = min(lens.zoomFactor, device.maxAvailableVideoZoomFactor)
                device.unlockForConfiguration()
            }
        }
    }

    // MARK: - Exposure

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else { return }
            do {
                try device.lockForConfiguration()
                
                // Clamp to device limits
                let minBias = device.minExposureTargetBias
                let maxBias = device.maxExposureTargetBias
                let clampedBias = max(minBias, min(maxBias, bias))
                
                device.setExposureTargetBias(clampedBias)
                device.unlockForConfiguration()
                
                DispatchQueue.main.async { self.exposureBias = clampedBias }
            } catch {
                // Ignore error
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

    // MARK: - Switch Camera

    func switchCamera() {
        let newValue = !isUsingFrontCamera
        DispatchQueue.main.async {
            self.isUsingFrontCamera = newValue
            self.selectedLens = .wide
        }
        sessionQueue.async { [weak self] in
            self?.configureSession(useFront: newValue, lens: .wide)
        }
    }

    func switchLens(_ lens: LensType) {
        guard !isUsingFrontCamera else { return }
        DispatchQueue.main.async { self.selectedLens = lens }
        sessionQueue.async { [weak self] in
            self?.configureSession(useFront: false, lens: lens)
        }
    }

    func cycleFlash() {
        guard !isUsingFrontCamera else { return }
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    // MARK: - Capture Photo

    func capturePhoto(aspectRatio: AspectRatioMode = .free) {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality

        pendingAspectRatio = aspectRatio

        if !isUsingFrontCamera {
            settings.flashMode = flashMode
        } else {
            DispatchQueue.main.async {
                UIApplication.shared
                    .connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?
                    .windows
                    .first?
                    .screen
                    .brightness = 1.0
            }
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrameCaptured?(sampleBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate & Crop Logic

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        DispatchQueue.main.async {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .screen
                .brightness = 0.5
        }

        guard error == nil, let photoData = photo.fileDataRepresentation() else { return }

        // Process crop and metadata on background queue
        processingQueue.async {
            let ratio = self.pendingAspectRatio

            guard let croppedData = self.cropImageWithMetadata(imageData: photoData, ratio: ratio) else {
                // Fallback to original if crop fails
                if let image = UIImage(data: photoData) {
                    DispatchQueue.main.async {
                        self.capturedImage = image
                        self.capturedPhotoData = photoData
                    }
                }
                return
            }

            if let image = UIImage(data: croppedData) {
                DispatchQueue.main.async {
                    self.capturedImage = image
                    self.capturedPhotoData = croppedData
                }
            }
        }
    }

    // MARK: - Image Cropping with Metadata Preservation

    private nonisolated func cropImageWithMetadata(imageData: Data, ratio: AspectRatioMode) -> Data? {
        if ratio == .free { return imageData }

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // Calculate crop rectangle
        var cropRect = CGRect.zero
        switch ratio {
        case .oneOne:
            let side = min(width, height)
            cropRect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
        case .sixteenNine:
            // Assuming portrait orientation by default for photos
            let targetHeight = width * (16.0 / 9.0)
            if targetHeight <= height {
                cropRect = CGRect(x: 0, y: (height - targetHeight) / 2, width: width, height: targetHeight)
            } else {
                let targetWidth = height * (9.0 / 16.0)
                cropRect = CGRect(x: (width - targetWidth) / 2, y: 0, width: targetWidth, height: height)
            }
        case .fourThree:
            // Assuming portrait orientation by default for photos
            let targetHeight = width * (4.0 / 3.0)
            if targetHeight <= height {
                cropRect = CGRect(x: 0, y: (height - targetHeight) / 2, width: width, height: targetHeight)
            } else {
                let targetWidth = height * (3.0 / 4.0)
                cropRect = CGRect(x: (width - targetWidth) / 2, y: 0, width: targetWidth, height: height)
            }
        case .free:
            return imageData
        }

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }

        // Write the cropped image back with the original metadata
        CGImageDestinationAddImage(destination, croppedCGImage, metadata as CFDictionary)

        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }

        return nil
    }
}
