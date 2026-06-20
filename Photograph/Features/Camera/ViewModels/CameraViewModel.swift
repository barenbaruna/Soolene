//
//  CameraViewModel.swift
//  Soolene
//

import AVFoundation
import Photos
import SwiftUI

/// The brain of the camera screen — binds UI state to feature coordinators.
@Observable
@MainActor
final class CameraViewModel {
    // MARK: - Analysis State

    var analysis = CompositionAnalysis()
    var selectedAspectRatio: AspectRatioMode = .fourThree {
        didSet {
            visionService.activeAspectRatio = selectedAspectRatio
            compositionCoordinator.recalculateTargetForAspectRatio(
                selectedAspectRatio,
                orientation: deviceOrientation,
                analysis: &analysis
            )
        }
    }

    /// Physical device orientation, updated via accelerometer — independent of system orientation lock.
    /// Used to keep Horizontal/Vertical target sockets in sync with the visually rotated grid overlay.
    var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    // MARK: - Capture State

    var showShutterFlash = false
    var lastSavedThumbnail: UIImage?
    var lastSavedAssetIdentifier: String?
    var saveError: String?
    var trackingQualityWarning: String?

    var timerLength: Int = 0
    var isCountingDown = false
    var countdownValue = 0

    var isFrontCameraZoomedOut = false
    var isSwitchingCamera = false
    var lastZoomApplyTime: CFAbsoluteTime = 0
    var pinchStartMultiplier: CGFloat?
    let zoomController = ZoomController()

    var activePanel: CameraControlPanel?
    var isZoomRulerActive = false
    private var zoomHideTask: Task<Void, Never>?
    private var exposureHideTask: Task<Void, Never>?

    func showZoomRulerTemporarily() {
        isZoomRulerActive = true
        activePanel = nil
        zoomHideTask?.cancel()
        zoomHideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run { self.isZoomRulerActive = false }
        }
    }

    func cancelZoomHideTimer() {
        zoomHideTask?.cancel()
    }

    func showExposureTemporarily() {
        activePanel = .exposure
        isZoomRulerActive = false
        exposureHideTask?.cancel()
        exposureHideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self.activePanel == .exposure {
                    self.activePanel = nil
                }
            }
        }
    }

    func cancelExposureHideTimer() {
        exposureHideTask?.cancel()
    }

    // MARK: - Permissions

    var cameraPermission: PermissionStatus = .notDetermined
    var photoAddPermission: PermissionStatus = .notDetermined
    var photoReadPermission: PermissionStatus = .notDetermined
    var isRequestingCameraPermission = false
    var isRequestingPhotoPermission = false
    var inlineToastMessage: String?

    var hasCameraPermission: Bool { cameraPermission.allowsCamera }
    var hasPhotoPermission: Bool { photoReadPermission.allowsPhotoBrowse }
    var hasRequiredPermissions: Bool { hasCameraPermission && hasPhotoPermission }

    // MARK: - Camera Mode

    var cameraMode: CameraMode = .rearSpatial
    var cameraManager: CameraManager

    // MARK: - Services

    var spatialEngine: SpatialCameraEngine
    let visionService: VisionService
    private let motionService = MotionService()

    // MARK: - Coordinators

    let captureCoordinator: CaptureCoordinator
    let sessionCoordinator: CameraSessionCoordinator
    let compositionCoordinator: CompositionCoordinator

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

        let sessionCoordinator = CameraSessionCoordinator(
            spatialEngine: spatialEngine,
            cameraManager: cameraManager,
            visionService: visionService
        )
        self.sessionCoordinator = sessionCoordinator
        self.captureCoordinator = CaptureCoordinator(
            spatialEngine: spatialEngine,
            cameraManager: cameraManager,
            visionService: visionService,
            sessionCoordinator: sessionCoordinator
        )
        self.compositionCoordinator = CompositionCoordinator(
            visionService: visionService,
            spatialEngine: spatialEngine
        )
        compositionCoordinator.onAutoSelectComposition = { [weak self] composition in
            self?.selectComposition(composition)
        }

        visionService.usesSpatialTracking = true

        visionService.onAnalysisUpdated = { [weak self] result in
            guard let self else { return }
            self.analysis = result
            // Phase transitions driven by vision are rear-camera only.
            // Front camera stays in .guiding with its chosen static grid.
            if self.cameraMode == .rearSpatial {
                self.compositionCoordinator.updatePhaseFromAnalysis(result)
            }
        }

        visionService.onMLSuggestionReady = { [weak self] generation, predictions in
            guard let self else { return }
            guard generation == self.visionService.guidanceGeneration else { return }
            self.compositionCoordinator.handleMLSuggestion(predictions, analysis: &self.analysis)
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
        }

        spatialEngine.onTrackingStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.updateTrackingWarning(for: state)
            }
        }

        spatialEngine.onSessionConfigured = { [weak self] in
            Task { @MainActor in
                self?.refreshARZoomAfterSessionStart()
            }
        }
    }

    // MARK: - Composition (domain-owned state)

    var compositionState: CompositionUIState { compositionCoordinator.uiState }

    var guidancePhase: GuidancePhase { compositionCoordinator.uiState.phase }
    var mlSuggestion: CompositionType? { compositionCoordinator.uiState.mlSuggestion }
    var userSelectedComposition: CompositionType? { compositionCoordinator.uiState.userSelectedComposition }
    var isSubjectPinned: Bool { compositionCoordinator.uiState.isSubjectPinned }
    var recommendedCompositionLabel: String? { compositionCoordinator.uiState.recommendedLabel }

    var sortedPickerCompositions: [CompositionType] {
        if cameraMode == .frontClassic {
            return [.center, .ruleOfThirds]
        }
        return compositionCoordinator.sortedPickerCompositions(predictions: analysis.mlPredictions)
    }

    var resolvedComposition: CompositionType {
        userSelectedComposition ?? analysis.detectedComposition
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await refreshPermissions()
        if hasCameraPermission {
            await spatialEngine.checkPermissionsAndSetup()
        }
        await loadLatestThumbnail()
        motionService.start()
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

    // MARK: - Tap-to-Compose

    func pinSubject(at normalisedPoint: CGPoint) {
        trackingQualityWarning = nil
        compositionCoordinator.pinSubject(
            at: normalisedPoint,
            cameraMode: cameraMode,
            analysis: &analysis
        )
    }

    func selectComposition(_ composition: CompositionType) {
        compositionCoordinator.selectComposition(
            composition,
            analysis: &analysis,
            aspectRatio: selectedAspectRatio,
            orientation: deviceOrientation
        )
    }

    /// Called when the physical device orientation changes (from NotificationCenter).
    /// Updates vision pipeline and recalculates locked target if guidance is active.
    func onDeviceOrientationChanged(_ newOrientation: UIDeviceOrientation) {
        guard newOrientation.isValidInterfaceOrientation || newOrientation.isLandscape else { return }
        deviceOrientation = newOrientation
        visionService.activeDeviceOrientation = newOrientation
        compositionCoordinator.recalculateTargetForAspectRatio(
            selectedAspectRatio,
            orientation: newOrientation,
            analysis: &analysis
        )
    }

    func clearPinnedSubject() {
        compositionCoordinator.clearPinnedSubject(cameraMode: cameraMode)
        trackingQualityWarning = nil
    }

    // MARK: - Private

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
}
