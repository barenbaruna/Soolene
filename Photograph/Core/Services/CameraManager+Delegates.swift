//
//  CameraManager+Delegates.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import AVFoundation
import UIKit

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
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
        
        onFrameCaptured?(syncedVideoData.sampleBuffer, depthData)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

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

        // Process image on background queue
        processingQueue.async {
            if let image = UIImage(data: photoData) {
                DispatchQueue.main.async {
                    self.capturedImage = image
                    self.capturedPhotoData = photoData
                }
            }
        }
    }
}
