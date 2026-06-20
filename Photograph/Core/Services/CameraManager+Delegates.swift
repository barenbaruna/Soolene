//
//  CameraManager+Delegates.swift
//  Soolene
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import OSLog
import UIKit

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        notifyPreviewFrameIfNeeded()
        onFrameCaptured?(sampleBuffer, nil)
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate

extension CameraManager: AVCaptureDataOutputSynchronizerDelegate {
    nonisolated func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection
    ) {
        guard let syncedVideoData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
            return
        }
        
        var depthData: AVDepthData? = nil
        if let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData {
            depthData = syncedDepthData.depthData
        }
        
        notifyPreviewFrameIfNeeded()
        onFrameCaptured?(syncedVideoData.sampleBuffer, depthData)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {

    private static let photoDelegateLog = Logger(subsystem: "com.barenbaruna.Soolene", category: "AVCapture")

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let telemetryPath = pendingHandoffTelemetryPath
        if let captureStart = pendingPhotoCaptureStart {
            Self.recordDelegateHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "avPhotoOutput",
                elapsedMs: Self.delegateElapsedMs(since: captureStart),
                success: error == nil
            )
        }

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

        if let error {
            DispatchQueue.main.async {
                self.isCapturingPhoto = false
                self.captureError = error.localizedDescription
                self.completePhotoWait(success: false)
                self.clearPendingHandoffTelemetry()
            }
            return
        }

        let fileDataStart = CFAbsoluteTimeGetCurrent()
        guard let photoData = photo.fileDataRepresentation() else {
            Self.recordDelegateHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "avFileData",
                elapsedMs: Self.delegateElapsedMs(since: fileDataStart),
                success: false
            )
            DispatchQueue.main.async {
                self.isCapturingPhoto = false
                self.captureError = "Photo capture returned no image."
                self.completePhotoWait(success: false)
                self.clearPendingHandoffTelemetry()
            }
            return
        }
        Self.recordDelegateHandoffStageIfNeeded(
            path: telemetryPath,
            stage: "avFileData",
            elapsedMs: Self.delegateElapsedMs(since: fileDataStart),
            success: true,
            detail: "bytes=\(photoData.count)"
        )

        if let image = UIImage(data: photoData)?.cgImage {
            Self.photoDelegateLog.info(
                "AV photo processed \(image.width)x\(image.height) bytes=\(photoData.count)"
            )
        }

        // Process crop and metadata on background queue
        processingQueue.async {
            let ratio = self.pendingAspectRatio

            let cropStart = CFAbsoluteTimeGetCurrent()
            guard let croppedData = ImageCropHelper.cropImageWithMetadata(imageData: photoData, ratio: ratio) else {
                Self.recordDelegateHandoffStageIfNeeded(
                    path: telemetryPath,
                    stage: "avCropMetadata",
                    elapsedMs: Self.delegateElapsedMs(since: cropStart),
                    success: false
                )
                let decodeStart = CFAbsoluteTimeGetCurrent()
                if let image = UIImage(data: photoData) {
                    Self.recordDelegateHandoffStageIfNeeded(
                        path: telemetryPath,
                        stage: "avDecodePreview",
                        elapsedMs: Self.delegateElapsedMs(since: decodeStart),
                        success: true
                    )
                    DispatchQueue.main.async {
                        self.capturedImage = image
                        self.capturedPhotoData = photoData
                        self.isCapturingPhoto = false
                        self.completePhotoWait(success: true)
                        self.clearPendingHandoffTelemetry()
                    }
                } else {
                    Self.recordDelegateHandoffStageIfNeeded(
                        path: telemetryPath,
                        stage: "avDecodePreview",
                        elapsedMs: Self.delegateElapsedMs(since: decodeStart),
                        success: false
                    )
                    DispatchQueue.main.async {
                        self.isCapturingPhoto = false
                        self.captureError = "Could not process captured image."
                        self.completePhotoWait(success: false)
                        self.clearPendingHandoffTelemetry()
                    }
                }
                return
            }
            Self.recordDelegateHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "avCropMetadata",
                elapsedMs: Self.delegateElapsedMs(since: cropStart),
                success: true,
                detail: "bytes=\(croppedData.count)"
            )

            let decodeStart = CFAbsoluteTimeGetCurrent()
            if let image = UIImage(data: croppedData) {
                Self.recordDelegateHandoffStageIfNeeded(
                    path: telemetryPath,
                    stage: "avDecodePreview",
                    elapsedMs: Self.delegateElapsedMs(since: decodeStart),
                    success: true
                )
                DispatchQueue.main.async {
                    self.capturedImage = image
                    self.capturedPhotoData = croppedData
                    self.isCapturingPhoto = false
                    self.completePhotoWait(success: true)
                    self.clearPendingHandoffTelemetry()
                }
            } else {
                Self.recordDelegateHandoffStageIfNeeded(
                    path: telemetryPath,
                    stage: "avDecodePreview",
                    elapsedMs: Self.delegateElapsedMs(since: decodeStart),
                    success: false
                )
                DispatchQueue.main.async {
                    self.isCapturingPhoto = false
                    self.captureError = "Could not process captured image."
                    self.completePhotoWait(success: false)
                    self.clearPendingHandoffTelemetry()
                }
            }
        }
    }

    private func clearPendingHandoffTelemetry() {
        pendingHandoffTelemetryPath = nil
        pendingPhotoCaptureStart = nil
    }

    private static func recordDelegateHandoffStageIfNeeded(
        path: CaptureTelemetry.CapturePath?,
        stage: String,
        elapsedMs: Int,
        success: Bool? = nil,
        detail: String? = nil
    ) {
        guard let path else { return }
        CaptureTelemetry.recordHandoffStage(
            path: path,
            stage: stage,
            elapsedMs: elapsedMs,
            success: success,
            detail: detail
        )
    }

    private static func delegateElapsedMs(since start: CFAbsoluteTime) -> Int {
        Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    }
}
