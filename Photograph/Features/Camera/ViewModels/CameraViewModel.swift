//
//  CameraViewModel.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import ARKit
import AVFoundation
import Photos
import SwiftUI

/// The brain of the camera screen — binds UI state to feature coordinators.
@Observable
@MainActor
final class CameraViewModel {
    // MARK: - Analysis State

    var analysis = CompositionAnalysis()
    var selectedAspectRatio: AspectRatioMode = .free

    // MARK: - Guidance Phase (stored for @Observable UI updates)

    var guidancePhase: GuidancePhase = .scanning
    var mlSuggestion: CompositionType? = nil
    var userSelectedComposition: CompositionType? = nil
    var isSubjectPinned: Bool = false
    var recommendedCompositionLabel: String? = nil

    // MARK: - Capture State

    var showShutterFlash = false
    var lastSavedThumbnail: UIImage?
    var saveError: String?
    var trackingQualityWarning: String?

    var timerLength: Int = 0
    var isCountingDown = false
    var countdownValue = 0
    var isSwitchingCamera = false
    var zoomFactor: CGFloat = 1
    private var lastZoomApplyTime: CFAbsoluteTime = 0

    // MARK: - Permissions

    var hasCameraPermission = false
    var hasPhotoPermission = false

    // MARK: - Camera Mode

    var cameraMode: CameraMode = .rearSpatial
    var cameraManager: CameraManager

    // MARK: - Services

    var spatialEngine: SpatialCameraEngine
    private let visionService: VisionService
    private let motionService = MotionService()

    // MARK: - Coordinators

    private let captureCoordinator: CaptureCoordinator
    private let sessionCoordinator: CameraSessionCoordinator
    private let compositionCoordinator: CompositionCoordinator

    // MARK: - Motion State

    var levelAngle: Double = 0

    // MARK: - Init

    init() {
        let visionService = VisionService()
        let spatialEngine = SpatialCameraEngine()
        let cameraManager = CameraManager()

        self.visionService = visionService
        self.spatialEngine = spatialEngine
        self.cameraManager = cameraManager

        self.captureCoordinator = CaptureCoordinator(
            spatialEngine: spatialEngine,
            cameraManager: cameraManager,
            visionService: visionService
        )
        self.sessionCoordinator = CameraSessionCoordinator(
            spatialEngine: spatialEngine,
            cameraManager: cameraManager,
            visionService: visionService
        )
        self.compositionCoordinator = CompositionCoordinator(
            visionService: visionService,
            spatialEngine: spatialEngine
        )

        visionService.usesSpatialTracking = true

        visionService.onAnalysisUpdated = { [weak self] result in
            guard let self else { return }
            self.analysis = result
            self.compositionCoordinator.updatePhaseFromAnalysis(result)
            self.syncCompositionState()
        }

        visionService.onMLSuggestionReady = { [weak self] predictions in
            guard let self else { return }
            self.compositionCoordinator.handleMLSuggestion(predictions, analysis: &self.analysis)
            self.syncCompositionState()
        }

        spatialEngine.shouldProcessVisionFrame = { @Sendable in
            visionService.shouldProcessVisionFrame()
        }

        spatialEngine.onFrameUpdated = { @Sendable packet in
            visionService.processSpatialFramePacket(packet)
        }

        spatialEngine.onSubjectLockResult = { @Sendable [weak self] quality in
            Task { @MainActor in
                guard let self, let quality else { return }
                switch quality {
                case .raycastHit, .depthPlacement:
                    if self.trackingQualityWarning?.contains("approximate") == true {
                        self.trackingQualityWarning = nil
                    }
                case .estimatedFallback:
                    self.trackingQualityWarning = "Subject lock is approximate — point at a textured surface."
                }
            }
        }

        motionService.onAttitudeUpdated = { [weak self] in
            guard let self else { return }
            self.levelAngle = self.motionService.rollDegrees
            self.visionService.deviceRollDegrees = self.motionService.rollDegrees
        }

        cameraManager.onFrameCaptured = { @Sendable [visionService] sampleBuffer, depthData in
            visionService.processFrame(sampleBuffer, depthData: depthData)
        }

        sessionCoordinator.onGuidanceReset = { [weak self] in
            self?.compositionCoordinator.resetGuidanceState()
            self?.syncCompositionState()
        }
    }

    private func syncCompositionState() {
        guidancePhase = compositionCoordinator.guidancePhase
        mlSuggestion = compositionCoordinator.mlSuggestion
        userSelectedComposition = compositionCoordinator.userSelectedComposition
        isSubjectPinned = compositionCoordinator.isSubjectPinned
        recommendedCompositionLabel = compositionCoordinator.recommendedCompositionLabel
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await checkPermissions()
        await spatialEngine.checkPermissionsAndSetup()
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
        sessionCoordinator.pauseSessions(cameraMode: cameraMode)
        motionService.stop()
    }

    func pauseSession() {
        sessionCoordinator.pauseSessions(cameraMode: cameraMode)
    }

    func resumeSession() {
        sessionCoordinator.resumeSession(cameraMode: cameraMode)
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

        Task {
            if cameraMode == .rearSpatial {
                await sessionCoordinator.switchToFrontClassic(
                    hasCameraPermission: hasCameraPermission,
                    checkPermissions: { await self.checkPermissions() }
                )
                cameraMode = .frontClassic
                trackingQualityWarning = "Front camera uses 2D tracking — world lock unavailable."
            } else {
                await sessionCoordinator.switchToRearSpatial()
                cameraMode = .rearSpatial
                trackingQualityWarning = nil
            }
            isSwitchingCamera = false
        }
    }

    func switchLens(_ lens: LensType) {
        guard !isSwitchingCamera else { return }
        HapticManager.selection()
        zoomFactor = lens.zoomFactor
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setZoomFactor(lens.zoomFactor)
        case .frontClassic:
            guard cameraManager.isUsingFrontCamera else { return }
            cameraManager.setZoomFactor(lens.zoomFactor)
        }
    }

    func switchLens(_ rawValue: String) {
        guard let lens = LensType(rawValue: rawValue) else { return }
        switchLens(lens)
    }

    // MARK: - Preview Gestures

    func focusAndExpose(at normalizedPoint: CGPoint) {
        guard !isSwitchingCamera else { return }
        HapticManager.selection()
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.focusAndExpose(at: normalizedPoint)
        case .frontClassic:
            cameraManager.focusAndExpose(at: normalizedPoint)
        }
    }

    func updateZoom(magnification: CGFloat, isFinal: Bool) {
        guard !isSwitchingCamera else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if !isFinal, now - lastZoomApplyTime < 1.0 / 30.0 { return }
        lastZoomApplyTime = now

        let baseZoom = max(zoomFactor, 1)
        let nextZoom = baseZoom * magnification
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setZoomFactor(nextZoom)
            if isFinal {
                zoomFactor = min(max(nextZoom, 1), spatialEngine.maximumZoomFactor)
            }
        case .frontClassic:
            cameraManager.setZoomFactor(nextZoom)
            if isFinal {
                zoomFactor = min(max(nextZoom, 1), cameraManager.maximumZoomFactor)
            }
        }
    }

    // MARK: - Tap-to-Compose

    func pinSubject(at normalisedPoint: CGPoint) {
        trackingQualityWarning = nil
        compositionCoordinator.pinSubject(
            at: normalisedPoint,
            cameraMode: cameraMode,
            analysis: &analysis
        )
        syncCompositionState()
    }

    func selectComposition(_ composition: CompositionType) {
        compositionCoordinator.selectComposition(composition, analysis: &analysis)
        syncCompositionState()
    }

    func clearPinnedSubject() {
        compositionCoordinator.clearPinnedSubject(cameraMode: cameraMode)
        trackingQualityWarning = nil
        syncCompositionState()
    }

    func cycleFlash() {
        HapticManager.selection()
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.cycleFlash()
        case .frontClassic:
            break
        }
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
        guard !isSwitchingCamera else { return }
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.setExposureBias(bias)
        case .frontClassic:
            cameraManager.setExposureBias(bias)
        }
    }

    func resetExposure() {
        HapticManager.selection()
        setExposure(0)
    }

    func cycleExposure() {
        let current = exposureBias
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
        guard isCaptureReady else { return }
        isCountingDown = true
        countdownValue = timerLength

        Task {
            while countdownValue > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !isCountingDown { return }
                countdownValue -= 1
            }
            if isCountingDown {
                if isCaptureReady {
                    executeCapture()
                }
                isCountingDown = false
            }
        }
    }

    func cancelCountdown() {
        isCountingDown = false
    }

    private func executeCapture() {
        guard isCaptureReady, !isCapturing else { return }

        Task {
            await captureCoordinator.executeCapture(
                cameraMode: cameraMode,
                aspectRatio: selectedAspectRatio,
                isCaptureReady: isCaptureReady
            )

            await MainActor.run {
                HapticManager.capture()
                showShutterFlash = true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            showShutterFlash = false
        }
    }

    // MARK: - Review Actions

    func savePhoto() async {
        guard let data = activeCapturedPhotoData else { return }

        do {
            try await GalleryManager.shared.savePhoto(data, composition: resolvedComposition)

            if let image = UIImage(data: data) {
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

    var sortedPickerCompositions: [CompositionType] {
        compositionCoordinator.sortedPickerCompositions(predictions: analysis.mlPredictions)
    }

    // MARK: - Resolved Composition

    var resolvedComposition: CompositionType {
        userSelectedComposition ?? analysis.detectedComposition
    }

    var guidanceTip: String {
        if let warning = trackingQualityWarning {
            return warning
        }
        if let label = recommendedCompositionLabel,
           case .guiding = guidancePhase {
            return label
        }

        switch guidancePhase {
        case .scanning:
            if cameraMode == .rearSpatial, spatialEngine.trackingState != .normal {
                return "Move slowly while spatial tracking initializes"
            }
            return "Long-press your subject"
        case .subjectLocked:
            return mlSuggestion.map { "Best fit: \($0.shortLabel) — tap to change" }
                ?? "Analyzing scene for best composition"
        case .guiding(let comp):
            let technique = GuidanceEngine.techniqueForUserSelection(
                composition: comp,
                geometry: analysis.sceneGeometry
            )
            return technique.tip
        case .perfect:
            if isCaptureReady {
                return "Perfect. Capture now."
            }
            return "Hold steady — stabilizing tracking for capture"
        }
    }

    var showsDualAnchorGuidance: Bool {
        guard guidancePhase.isActive else { return false }
        guard userSelectedComposition != nil else { return false }
        return resolvedComposition != .horizontal
    }

    var isCaptureReady: Bool {
        captureCoordinator.isCaptureReady(
            cameraMode: cameraMode,
            guidancePhase: guidancePhase
        )
    }

    var shutterIsPerfect: Bool {
        guidancePhase.isPerfect && isCaptureReady
    }

    var activeCapturedPhotoData: Data? {
        captureCoordinator.activeCapturedPhotoData
    }

    var captureError: String? {
        captureCoordinator.activeCaptureError
    }

    func clearCaptureError() {
        captureCoordinator.clearCaptureErrors()
    }

    // MARK: - Computed UI Properties

    var flashSymbolName: String {
        switch activeFlashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    var isFrontCamera: Bool { cameraMode == .frontClassic }

    var activeFlashMode: AVCaptureDevice.FlashMode {
        switch cameraMode {
        case .rearSpatial: spatialEngine.flashMode
        case .frontClassic: cameraManager.flashMode
        }
    }

    var flashMode: AVCaptureDevice.FlashMode { activeFlashMode }

    var isFlashActive: Bool {
        activeFlashMode == .on || activeFlashMode == .auto
    }

    var exposureBias: Float {
        switch cameraMode {
        case .rearSpatial: spatialEngine.exposureBias
        case .frontClassic: cameraManager.exposureBias
        }
    }

    var selectedLens: String {
        LensType.closest(toZoom: zoomFactor).rawValue
    }

    var isCapturing: Bool {
        captureCoordinator.isCapturing(cameraMode: cameraMode)
    }

    var availableLenses: [LensType] {
        cameraMode == .frontClassic ? [.wide] : LensType.availableOnDevice
    }
}

// MARK: - LensType Zoom Helper

private extension LensType {
    static func closest(toZoom zoom: CGFloat) -> LensType {
        let candidates: [LensType] = [.ultraWide, .wide, .twoX, .fiveX]
        return candidates.min(by: { abs($0.zoomFactor - zoom) < abs($1.zoomFactor - zoom) }) ?? .wide
    }
}
