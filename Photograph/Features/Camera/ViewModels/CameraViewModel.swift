//
//  CameraViewModel.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import Photos
import SwiftUI

/// The brain of the camera screen.
/// Connects CameraManager, VisionService, and GalleryManager.
@Observable
@MainActor
final class CameraViewModel {
    // MARK: - Analysis State

    var analysis = CompositionAnalysis()
    var selectedAspectRatio: AspectRatioMode = .free

    // MARK: - Capture State

    var showShutterFlash = false
    var lastSavedThumbnail: UIImage?
    var saveError: String?

    // Timer state
    var timerLength: Int = 0 // 0, 3, 10
    var isCountingDown = false
    var countdownValue = 0

    // MARK: - Permissions

    var hasCameraPermission = false
    var hasPhotoPermission = false

    // MARK: - Services

    var cameraManager = CameraManager()
    private let visionService = VisionService()
    private let motionService = MotionService()

    // MARK: - Motion State

    /// Live roll angle from CoreMotion. Used to enhance horizontal/level guidance.
    var levelAngle: Double = 0

    // MARK: - Tap-to-Guide State

    /// True when the user has manually pinned a subject by tapping the preview.
    var isSubjectPinned: Bool = false

    // MARK: - Init

    init() {
        visionService.onAnalysisUpdated = { [weak self] result in
            guard let self else { return }
            self.analysis = result
        }

        let visionService = self.visionService
        cameraManager.onFrameCaptured = { @Sendable sampleBuffer, depthData in
            visionService.processFrame(sampleBuffer, depthData: depthData)
        }

        // Keep VisionService in sync with the active camera
        visionService.isFrontCamera = cameraManager.isUsingFrontCamera

        motionService.onAttitudeUpdated = { [weak self] in
            self?.levelAngle = self?.motionService.rollDegrees ?? 0
        }
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await checkPermissions()
        await cameraManager.checkPermissionsAndSetup()
        await loadLatestThumbnail()
        motionService.start()
    }

    private func loadLatestThumbnail() async {
        guard let assets = await GalleryManager.shared.fetchAllPhotos(),
              let latestAsset = assets.firstObject else { return }

        let size = CGSize(width: 80, height: 80)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        PHImageManager.default().requestImage(
            for: latestAsset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            if let img = img {
                Task { @MainActor in
                    self.lastSavedThumbnail = img
                }
            }
        }
    }

    func onDisappear() {
        cameraManager.stopSession()
        motionService.stop()
    }

    func pauseSession() {
        cameraManager.stopSession()
    }

    func resumeSession() {
        Task { await cameraManager.checkPermissionsAndSetup() }
    }

    // MARK: - Permissions

    private func checkPermissions() async {
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if camStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            hasCameraPermission = granted
        } else {
            hasCameraPermission = camStatus == .authorized
        }

        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if photoStatus == .notDetermined {
            let result = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            hasPhotoPermission = (result == .authorized || result == .limited)
        } else {
            hasPhotoPermission = (photoStatus == .authorized || photoStatus == .limited)
        }
    }

    // MARK: - Camera Actions

    func switchCamera() {
        HapticManager.selection()
        cameraManager.switchCamera()
        // Immediately sync front-camera flag so Vision uses the correct orientation
        visionService.isFrontCamera = cameraManager.isUsingFrontCamera
    }

    func switchLens(_ lens: LensType) {
        HapticManager.selection()
        cameraManager.switchLens(lens)
    }
    
    func switchLens(_ rawValue: String) {
        guard let lens = LensType(rawValue: rawValue) else { return }
        switchLens(lens)
    }

    // MARK: - Tap-to-Guide

    /// Called when user taps on the camera preview to declare the subject.
    /// `normalisedPoint` is in UIKit 0–1 coordinate space (tap.x / viewWidth, tap.y / viewHeight).
    func pinSubject(at normalisedPoint: CGPoint) {
        HapticManager.selection()
        isSubjectPinned = true
        visionService.pinSubject(at: normalisedPoint)
    }

    /// Clears the pinned subject (double-tap to reset), restoring Vision auto-detection.
    func clearPinnedSubject() {
        HapticManager.selection()
        isSubjectPinned = false
        visionService.clearPinnedSubject()
    }

    func cycleFlash() {
        HapticManager.selection()
        cameraManager.cycleFlash()
    }

    func cycleTimer() {
        HapticManager.selection()
        switch timerLength {
        case 0: timerLength = 3
        case 3: timerLength = 10
        case 10: timerLength = 0
        default: timerLength = 0
        }
    }

    func setExposure(_ bias: Float) {
        cameraManager.setExposureBias(bias)
    }

    func cycleExposure() {
        let current = cameraManager.exposureBias
        let next: Float
        if current == 0 { next = 1.0 }
        else if current == 1.0 { next = 2.0 }
        else if current == 2.0 { next = -2.0 }
        else if current == -2.0 { next = -1.0 }
        else { next = 0.0 }
        HapticManager.selection()
        setExposure(next)
    }

    func capturePhoto() {
        if timerLength > 0 {
            startCountdown()
        } else {
            executeCapture()
        }
    }

    private func startCountdown() {
        guard !isCountingDown else { return }
        isCountingDown = true
        countdownValue = timerLength

        // Simple recursive countdown using Task
        Task {
            while countdownValue > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !isCountingDown { return } // Cancelled
                countdownValue -= 1
            }
            if isCountingDown {
                executeCapture()
                isCountingDown = false
            }
        }
    }

    func cancelCountdown() {
        isCountingDown = false
    }

    private func executeCapture() {
        HapticManager.capture()
        // Trigger UI flash
        showShutterFlash = true
        // Turn off flash after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            showShutterFlash = false
        }

        cameraManager.capturedImage = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturePhoto(aspectRatio: selectedAspectRatio)
    }

    // MARK: - Review Actions

    func savePhoto() async {
        guard let data = cameraManager.capturedPhotoData else { return }

        do {
            try await GalleryManager.shared.savePhoto(data, composition: analysis.detectedComposition)

            // Generate thumbnail for the gallery button
            if let image = UIImage(data: data) {
                // Resize for thumbnail to save memory
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80))
                let thumb = renderer.image { _ in
                    image.draw(in: CGRect(x: 0, y: 0, width: 80, height: 80))
                }
                lastSavedThumbnail = thumb
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Resolved Composition

    /// Returns the currently detected composition type.
    var resolvedComposition: CompositionType {
        analysis.detectedComposition
    }

    var activeTechnique: CompositionTechnique? {
        analysis.activeTechnique
    }

    /// Label for the top badge (e.g., "Rule of Thirds").
    var compositionLabel: String {
        analysis.detectedComposition.rawValue
    }

    // MARK: - Computed UI Properties

    var flashSymbolName: String {
        if cameraManager.isUsingFrontCamera { return "bolt.slash.fill" }
        switch cameraManager.flashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    var isFrontCamera: Bool {
        cameraManager.isUsingFrontCamera
    }

    var isFlashActive: Bool {
        cameraManager.flashMode == .on
    }

    var exposureBias: Float {
        cameraManager.exposureBias
    }

    var selectedLens: String {
        cameraManager.selectedLens.rawValue
    }
}
