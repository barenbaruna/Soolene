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

    // MARK: - Guidance Phase

    /// The current phase of the composition guidance system.
    /// Drives all UI state: overlays, picker visibility, tip text, animations.
    var guidancePhase: GuidancePhase = .scanning

    /// ML-suggested composition, shown as "★ Recommended" in the picker.
    /// Set ONCE when the user locks a subject.
    var mlSuggestion: CompositionType? = nil

    /// The composition chosen by the user via the picker.
    /// This is the authoritative source for grid overlay and guidance.
    var userSelectedComposition: CompositionType? = nil

    // MARK: - Capture State

    var showShutterFlash = false
    var lastSavedThumbnail: UIImage?
    var saveError: String?

    // Timer state
    var timerLength: Int = 0 // 0, 3, 10
    var isCountingDown = false
    var countdownValue = 0
    var isSwitchingCamera = false
    var zoomFactor: CGFloat = 1

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

            // Tracking-lost detection: if subject was pinned but tracker cleared it
            if self.isSubjectPinned,
               self.guidancePhase.isLocked,
               result.sceneGeometry.userPinnedSubject == nil {
                // Vision lost the tracked subject — gracefully reset
                HapticManager.notification(.warning)
                self.isSubjectPinned = false
                self.guidancePhase = .scanning
                self.userSelectedComposition = nil
                self.mlSuggestion = nil
                self.visionService.isMLEnabled = true
                return
            }

            // Auto-transition to perfect/guiding based on alignment
            if case .guiding(let comp) = self.guidancePhase {
                if result.isCompositionPerfect {
                    self.guidancePhase = .perfect(composition: comp)
                    HapticManager.notification(.success)
                }
            } else if case .perfect(let comp) = self.guidancePhase {
                if !result.isCompositionPerfect {
                    self.guidancePhase = .guiding(composition: comp)
                }
            }
        }

        // One-shot ML suggestion callback
        visionService.onMLSuggestionReady = { [weak self] predictions in
            guard let self else { return }
            self.mlSuggestion = GuidanceEngine.suggestComposition(predictions: predictions)
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
        guard !isSwitchingCamera else { return }

        HapticManager.selection()
        isSwitchingCamera = true
        cameraManager.switchCamera { [weak self] in
            self?.isSwitchingCamera = false
        }
        // Immediately sync front-camera flag so Vision uses the correct orientation
        visionService.isFrontCamera = cameraManager.isUsingFrontCamera
    }

    func switchLens(_ lens: LensType) {
        HapticManager.selection()
        cameraManager.switchLens(lens)
        zoomFactor = lens.zoomFactor
    }
    
    func switchLens(_ rawValue: String) {
        guard let lens = LensType(rawValue: rawValue) else { return }
        switchLens(lens)
    }

    // MARK: - Preview Gestures

    func focusAndExpose(at devicePoint: CGPoint) {
        HapticManager.selection()
        cameraManager.focusAndExpose(at: devicePoint)
    }

    func updateZoom(magnification: CGFloat, isFinal: Bool) {
        let baseZoom = max(zoomFactor, 1)
        let nextZoom = baseZoom * magnification
        cameraManager.setZoomFactor(nextZoom)

        if isFinal {
            zoomFactor = min(max(nextZoom, 1), cameraManager.maximumZoomFactor)
        }
    }

    // MARK: - Tap-to-Compose

    /// Called when user long-presses on the camera preview to declare the subject.
    /// Transitions to `.subjectLocked` phase and triggers one-shot ML prediction.
    func pinSubject(at normalisedPoint: CGPoint) {
        HapticManager.selection()
        isSubjectPinned = true
        visionService.pinSubject(at: normalisedPoint)

        // Transition to subjectLocked phase
        guidancePhase = .subjectLocked(subjectPoint: normalisedPoint)
        mlSuggestion = nil

        // ML runs once to suggest a composition
        // The onMLSuggestionReady callback will fire after the next slow-tier pass.
        // For faster response, check if we already have predictions from a recent frame.
        if !analysis.mlPredictions.isEmpty {
            mlSuggestion = GuidanceEngine.suggestComposition(predictions: analysis.mlPredictions)
        }
        // Keep ML enabled briefly so the next slow-tier cycle fires the suggestion
        visionService.isMLEnabled = true
    }

    /// User selects a composition from the picker.
    /// Transitions to `.guiding` phase and disables ML to prevent interference.
    func selectComposition(_ composition: CompositionType) {
        HapticManager.selection()
        userSelectedComposition = composition
        guidancePhase = .guiding(composition: composition)

        // Disable ML slow tier — the user has declared their intent
        visionService.isMLEnabled = false

        // Update analysis to use the user-selected composition for alignment calculation
        analysis.detectedComposition = composition

        // Reset locked target so AlignmentAnalyzer recalculates for the new composition
        analysis.sceneGeometry.lockedTargetPoint = nil
    }

    /// Clears the pinned subject (double-tap to reset), restoring scanning mode.
    func clearPinnedSubject() {
        HapticManager.selection()
        isSubjectPinned = false
        visionService.clearPinnedSubject()

        // Reset to scanning
        guidancePhase = .scanning
        userSelectedComposition = nil
        mlSuggestion = nil

        // Re-enable ML for the next subject lock
        visionService.isMLEnabled = true
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

    func resetExposure() {
        HapticManager.selection()
        setExposure(0)
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
            try await GalleryManager.shared.savePhoto(data, composition: resolvedComposition)

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

    /// Returns the currently active composition type.
    /// Priority: user-selected > ML-detected > default.
    var resolvedComposition: CompositionType {
        userSelectedComposition ?? analysis.detectedComposition
    }

    /// The guidance tip text for the current phase.
    var guidanceTip: String {
        switch guidancePhase {
        case .scanning:
            return "Long-press your subject"
        case .subjectLocked:
            return "Choose a composition"
        case .guiding(let comp):
            let technique = GuidanceEngine.techniqueForUserSelection(
                composition: comp,
                geometry: analysis.sceneGeometry
            )
            return technique.tip
        case .perfect:
            return "Perfect. Capture now."
        }
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

    var flashMode: AVCaptureDevice.FlashMode {
        cameraManager.flashMode
    }

    var isFlashActive: Bool {
        cameraManager.flashMode == .on || cameraManager.flashMode == .auto
    }

    var exposureBias: Float {
        cameraManager.exposureBias
    }

    var selectedLens: String {
        cameraManager.selectedLens.rawValue
    }
}
