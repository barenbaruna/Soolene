//
//  SpatialCameraEngine.swift
//  Photograph
//
//  Unified Spatial-Photo Engine: ARSession for world-locked tracking and
//  out-of-band high-resolution capture via captureHighResolutionFrame(using:).
//

import ARKit
import AVFoundation
import CoreImage
import OSLog
import UIKit

/// Result of attempting to lock a subject in world space.
enum SubjectLockQuality: Equatable {
    case raycastHit
    case depthPlacement
    case estimatedFallback
}

/// Manages ARKit world tracking, subject anchoring, and high-resolution capture.
@Observable
final class SpatialCameraEngine: NSObject, @unchecked Sendable {

    // MARK: - Observable State

    var isSessionRunning = false
    var isARKitSupported = ARWorldTrackingConfiguration.isSupported
    var flashMode: AVCaptureDevice.FlashMode = .off
    var exposureBias: Float = 0.0
    var capturedImage: UIImage?
    var capturedPhotoData: Data?
    var captureError: String?
    /// Last `ARError.code.rawValue` from hi-res capture failure (telemetry).
    var lastCaptureARErrorCode: Int?
    var trackingState: ARCamera.TrackingState = .notAvailable
    /// 0…1 progress toward stable tracking for hi-res capture.
    var trackingStabilityProgress: Float = 0
    var isCapturingHighResolution = false
    var lastLockQuality: SubjectLockQuality?
    var viewportSize: CGSize = .zero
    /// Last frame frozen for handoff overlay (Epic 3b UI).
    var handoffFrozenPreviewImage: UIImage?
    /// Active lens preset for telemetry (derived from display multiplier).
    var selectedLens: LensType = .wide
    /// User-facing zoom multiplier for handoff snapshot.
    var displayMultiplier: CGFloat = 1.0
    var isZoomPreviewApproximate = false

    /// The processed preview is driven by ARSCNView bound to `session`.
    let session = ARSession()
    private let sessionController: ARSessionController

    // MARK: - Callbacks

    var onFrameUpdated: (@Sendable (SpatialFramePacket) -> Void)?
    var onSubjectLockResult: (@Sendable (SubjectLockQuality?) -> Void)?
    var onTrackingStateChanged: ((ARCamera.TrackingState) -> Void)?
    /// Fired on the main queue after AR session run completes (used to refresh zoom profile).
    var onSessionConfigured: (() -> Void)?
    /// When false, the delegate skips pixel-buffer copy (Vision still receives projected subject).
    var shouldProcessVisionFrame: (@Sendable () -> Bool)?

    // MARK: - Private

    private let sessionQueue = DispatchQueue(label: "com.photograph.arSession", qos: .userInitiated)
    private let arStateLock = NSLock()
    private var worldConfiguration: ARWorldTrackingConfiguration? {
        sessionController.worldConfiguration
    }
    private var subjectAnchor: ARAnchor?
    private(set) var isSubjectLocked = false
    private var pendingLockPoint: CGPoint?

    /// Protected by `arStateLock` — readable synchronously from the ARSession delegate.
    private var sessionViewportSize: CGSize = .zero
    private var sessionInterfaceOrientation: UIInterfaceOrientation = .portrait

    var pendingAspectRatio: AspectRatioMode = .free

    private(set) var isSessionConfigured = false
    private var isVisionPausedForCapture = false
    private var consecutiveNormalFrames = 0
    private var visionFrameProcessCounter = 0
    private var pendingSessionRecovery = false
    private var sessionCaptureActive = false
    private var pendingDeviceVideoZoom: CGFloat = 1.0

    private static let captureCIContext = CIContext(options: nil)
    private static let zoomLog = Logger(subsystem: "com.barenbaruna.Photograph", category: "ZoomDiscovery")
    private static let requiredNormalFramesForCapture = 3
    private static let visionProcessEveryNthFrame = 2

    private static func visionFrameInterval() -> Int {
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical: return 4
        case .fair: return 3
        default: return visionProcessEveryNthFrame
        }
    }
    private static let captureLog = Logger(subsystem: "com.barenbaruna.Photograph", category: "SpatialCapture")

    // MARK: - Lifecycle

    override init() {
        sessionController = ARSessionController(session: session)
        super.init()
        session.delegate = self
    }

    func checkPermissionsAndSetup() async {
        guard ARWorldTrackingConfiguration.isSupported else {
            await MainActor.run { isARKitSupported = false }
            return
        }

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
                self?.configureAndRun(resetAnchors: true)
                continuation.resume()
            }
        }
    }

    private func configureAndRun(resetAnchors: Bool) {
        guard sessionController.buildConfiguration() != nil else { return }

        arStateLock.lock()
        let reattach = resetAnchors ? nil : subjectAnchor
        if resetAnchors {
            subjectAnchor = nil
            isSubjectLocked = false
        }
        arStateLock.unlock()

        sessionController.run(resetAnchors: resetAnchors, reattach: reattach)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSessionRunning = true
            self.isARKitSupported = true
            self.isSessionConfigured = true
            self.notifySessionConfiguredAndReapplyZoom()
        }
    }

    private func notifySessionConfiguredAndReapplyZoom() {
        // ARKit exposes `configurableCaptureDeviceForPrimaryCamera` only after run.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            let primaryType = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera?
                .deviceType.rawValue
            CaptureTelemetry.recordARPrimaryCamera(deviceType: primaryType)
            self?.onSessionConfigured?()
            self?.reapplyPendingDeviceZoom()
        }
    }

    /// Resumes an existing configuration without resetting world anchors.
    func resumeSessionPreservingAnchors() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.sessionController.runPreservingConfiguration()
            DispatchQueue.main.async {
                self.isSessionRunning = true
                self.isSessionConfigured = true
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.sessionController.worldConfiguration == nil {
                self.configureAndRun(resetAnchors: true)
            } else {
                self.sessionController.runPreservingConfiguration()
                DispatchQueue.main.async { self.isSessionRunning = true }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.sessionController.pause()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }

    func stopSessionAndWait() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                self?.sessionController.pause()
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                    continuation.resume()
                }
            }
        }
    }

    func updateViewport(size: CGSize, orientation: UIInterfaceOrientation) {
        arStateLock.lock()
        if size.width > 0, size.height > 0 {
            sessionViewportSize = size
        }
        sessionInterfaceOrientation = orientation
        arStateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.viewportSize = size
        }
    }

    // MARK: - Subject Locking

    func lockSubject(at normalizedPoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let frame = self.session.currentFrame {
                self.performLock(at: normalizedPoint, frame: frame)
            } else {
                self.pendingLockPoint = normalizedPoint
            }
        }
    }

    func clearSubjectAnchor() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.arStateLock.lock()
            let anchor = self.subjectAnchor
            self.subjectAnchor = nil
            self.isSubjectLocked = false
            self.pendingLockPoint = nil
            self.arStateLock.unlock()

            if let anchor {
                self.session.remove(anchor: anchor)
            }
            DispatchQueue.main.async {
                self.lastLockQuality = nil
            }
        }
    }

    private func projectedSubjectPoint(for frame: ARFrame) -> CGPoint? {
        arStateLock.lock()
        let anchor = subjectAnchor
        let viewport = sessionViewportSize
        let orientation = sessionInterfaceOrientation
        arStateLock.unlock()

        guard let anchor, viewport.width > 0, viewport.height > 0 else { return nil }

        return CoordinateMapper.projectAnchor(
            anchor,
            frame: frame,
            viewportSize: viewport,
            interfaceOrientation: orientation
        )
    }

    private func imageNormalizedPoint(viewNormalized: CGPoint, frame: ARFrame) -> CGPoint {
        arStateLock.lock()
        let viewport = sessionViewportSize
        arStateLock.unlock()
        let imageSize = frame.camera.imageResolution
        return CoordinateMapper.viewNormalizedToImageNormalized(
            viewNormalized: viewNormalized,
            viewSize: viewport,
            imageSize: CGSize(width: imageSize.width, height: imageSize.height)
        )
    }

    private func performLock(at normalizedPoint: CGPoint, frame: ARFrame) {
        arStateLock.lock()
        if let existing = subjectAnchor {
            session.remove(anchor: existing)
            subjectAnchor = nil
        }
        arStateLock.unlock()

        let imagePoint = imageNormalizedPoint(viewNormalized: normalizedPoint, frame: frame)

        // Prefer scene depth at the tap (person/object) before plane raycast.
        if let depthMeters = sceneDepth(at: imagePoint, frame: frame),
           depthMeters > 0.1, depthMeters < 10 {
            let transform = worldTransform(
                for: normalizedPoint,
                distanceMeters: depthMeters,
                frame: frame
            )
            installAnchor(at: transform, quality: .depthPlacement)
            return
        }

        let raycastTargets: [(ARRaycastQuery.Target, ARRaycastQuery.TargetAlignment)] = [
            (.existingPlaneGeometry, .any),
            (.estimatedPlane, .any),
            (.existingPlaneInfinite, .any)
        ]

        for (target, alignment) in raycastTargets {
            let query = frame.raycastQuery(from: imagePoint, allowing: target, alignment: alignment)
            let results = session.raycast(query)
            if let hit = results.first {
                installAnchor(at: hit.worldTransform, quality: .raycastHit)
                return
            }
        }

        let fallbackDistance: Float = 1.5
        let transform = worldTransform(
            for: normalizedPoint,
            distanceMeters: fallbackDistance,
            frame: frame
        )
        installAnchor(at: transform, quality: .estimatedFallback)
    }

    private func installAnchor(at transform: simd_float4x4, quality: SubjectLockQuality) {
        let anchor = ARAnchor(transform: transform)
        session.add(anchor: anchor)
        arStateLock.lock()
        subjectAnchor = anchor
        isSubjectLocked = true
        pendingLockPoint = nil
        arStateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.lastLockQuality = quality
            self?.onSubjectLockResult?(quality)
        }
    }

    private func sceneDepth(at normalizedPoint: CGPoint, frame: ARFrame) -> Float? {
        if let depthMap = frame.smoothedSceneDepth?.depthMap {
            return DepthAnalyzer.extractDepth(at: normalizedPoint, from: depthMap)
        }
        if let depthMap = frame.sceneDepth?.depthMap {
            return DepthAnalyzer.extractDepth(at: normalizedPoint, from: depthMap)
        }
        return nil
    }

    private func worldTransform(
        for normalizedPoint: CGPoint,
        distanceMeters: Float,
        frame: ARFrame
    ) -> simd_float4x4 {
        arStateLock.lock()
        let orientation = sessionInterfaceOrientation
        let viewport = sessionViewportSize
        arStateLock.unlock()

        let camera = frame.camera
        let viewMatrix = camera.viewMatrix(for: orientation)
        let projectionMatrix = camera.projectionMatrix(
            for: orientation,
            viewportSize: viewport,
            zNear: 0.001,
            zFar: 1000
        )

        let clipX = Float(normalizedPoint.x) * 2 - 1
        let clipY = Float(1 - normalizedPoint.y) * 2 - 1

        let projectionInverse = projectionMatrix.inverse
        let viewInverse = viewMatrix.inverse

        let clipNear = simd_float4(clipX, clipY, -1, 1)
        let clipFar = simd_float4(clipX, clipY, 1, 1)

        var worldNear = projectionInverse * clipNear
        var worldFar = projectionInverse * clipFar
        worldNear /= worldNear.w
        worldFar /= worldFar.w

        worldNear = viewInverse * worldNear
        worldFar = viewInverse * worldFar

        let origin = simd_float3(worldNear.x, worldNear.y, worldNear.z)
        let end = simd_float3(worldFar.x, worldFar.y, worldFar.z)
        let direction = simd_normalize(end - origin)
        let position = origin + direction * distanceMeters

        var transform = matrix_identity_float4x4
        transform.columns.3 = simd_float4(position.x, position.y, position.z, 1)
        return transform
    }

    // MARK: - Camera Controls

    func focusAndExpose(at normalizedPoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let frame = self.session.currentFrame,
                  let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera
            else { return }

            let imagePoint = self.imageNormalizedPoint(viewNormalized: normalizedPoint, frame: frame)

            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = imagePoint
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = imagePoint
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                    }
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore transient configuration failures.
            }
        }
    }

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera
            else { return }

            do {
                try device.lockForConfiguration()
                let clamped = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, bias))
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.exposureBias = clamped }
            } catch {
                // Ignore transient configuration failures.
            }
        }
    }

    /// Applies device `videoZoomFactor` from mapped AR guidance zoom.
    func setZoomFactor(_ deviceVideoZoomFactor: CGFloat) {
        pendingDeviceVideoZoom = deviceVideoZoomFactor
        applyPendingDeviceZoom()
    }

    func reapplyPendingDeviceZoom() {
        applyPendingDeviceZoom()
    }

    private func applyPendingDeviceZoom() {
        let factor = pendingDeviceVideoZoom
        DispatchQueue.main.async {
            guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else {
                Self.zoomLog.warning("zoom_apply skipped — no configurable AR capture device")
                return
            }

            do {
                try device.lockForConfiguration()
                let clamped = min(
                    max(factor, device.minAvailableVideoZoomFactor),
                    device.maxAvailableVideoZoomFactor
                )
                device.videoZoomFactor = clamped
                let readback = device.videoZoomFactor
                device.unlockForConfiguration()
                Self.zoomLog.debug(
                    """
                    zoom_apply device=\(device.deviceType.rawValue) \
                    requested=\(factor) applied=\(clamped) \
                    min=\(device.minAvailableVideoZoomFactor) max=\(device.maxAvailableVideoZoomFactor) \
                    readback=\(readback) visualPreview=\(self.displayMultiplier)
                    """
                )
            } catch {
                Self.zoomLog.error("zoom_apply failed: \(error.localizedDescription)")
            }
        }
    }

    func cycleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    // MARK: - AV Handoff Primitives (Option F)

    /// Captures world map, anchor transform, camera controls, and a frozen preview frame.
    func makeHandoffSnapshot(aspectRatio: AspectRatioMode) async -> CaptureHandoffSnapshot {
        await withCheckedContinuation { continuation in
            session.getCurrentWorldMap { [weak self] worldMap, error in
                guard let self else {
                    continuation.resume(returning: .empty(aspectRatio: aspectRatio))
                    return
                }
                if let error {
                    Self.captureLog.warning(
                        "World map snapshot failed: \(error.localizedDescription)"
                    )
                }
                self.sessionQueue.async {
                    let snapshot = self.buildHandoffSnapshotOnSessionQueue(
                        aspectRatio: aspectRatio,
                        worldMap: worldMap
                    )
                    DispatchQueue.main.async {
                        self.handoffFrozenPreviewImage = snapshot.frozenPreviewImage
                    }
                    continuation.resume(returning: snapshot)
                }
            }
        }
    }

    /// Pauses AR and vision processing so AVFoundation can claim the camera.
    func pauseForHandoff() async {
        arStateLock.lock()
        isVisionPausedForCapture = true
        arStateLock.unlock()
        await stopSessionAndWait()
    }

    /// Resumes AR after AV capture; waits up to `trackingTimeout` for stable tracking.
    func resumeAfterHandoff(
        _ snapshot: CaptureHandoffSnapshot,
        trackingTimeout: TimeInterval = 8,
        waitsForTrackingRecovery: Bool = true,
        telemetryPath: CaptureTelemetry.CapturePath? = nil
    ) async -> CaptureHandoffResumeResult {
        let anchorTransform = snapshot.subjectAnchorTransform
        let usedWorldMap = snapshot.worldMap != nil

        let runStart = CFAbsoluteTimeGetCurrent()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                let anchor = self.prepareSubjectAnchorForResume(from: anchorTransform)
                if let worldMap = snapshot.worldMap {
                    self.sessionController.runWithWorldMap(worldMap, reattach: anchor)
                } else {
                    self.sessionController.runAfterHandoffWithoutWorldMap(reattach: anchor)
                }
                self.consecutiveNormalFrames = 0
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                    self.isSessionConfigured = true
                    self.trackingStabilityProgress = 0
                    self.notifySessionConfiguredAndReapplyZoom()
                }
                self.arStateLock.lock()
                self.isVisionPausedForCapture = false
                self.arStateLock.unlock()
                continuation.resume()
            }
        }
        Self.recordHandoffStageIfNeeded(
            path: telemetryPath,
            stage: "arResumeRun",
            elapsedMs: Self.elapsedMs(since: runStart)
        )

        guard waitsForTrackingRecovery else {
            waitForTrackingRecoveryInBackground(
                timeout: trackingTimeout,
                telemetryPath: telemetryPath,
                recoveryStart: CFAbsoluteTimeGetCurrent(),
                usedWorldMap: usedWorldMap,
                anchorTransform: anchorTransform
            )
            return .recoveryDeferred
        }

        let recoveryStart = CFAbsoluteTimeGetCurrent()
        if await waitForTrackingRecovery(timeout: trackingTimeout) {
            Self.recordHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "trackingRecovery",
                elapsedMs: Self.elapsedMs(since: recoveryStart),
                success: true
            )
            return snapshot.worldMap != nil ? .recoveredWithWorldMap : .recoveredWithoutWorldMap
        }
        Self.recordHandoffStageIfNeeded(
            path: telemetryPath,
            stage: "trackingRecovery",
            elapsedMs: Self.elapsedMs(since: recoveryStart),
            success: false
        )

        if snapshot.worldMap != nil {
            Self.captureLog.warning("World map relocalization timed out — falling back without map")
            let fallbackRunStart = CFAbsoluteTimeGetCurrent()
            await resumeWithoutWorldMap(anchorTransform: anchorTransform)
            Self.recordHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "arResumeFallbackRun",
                elapsedMs: Self.elapsedMs(since: fallbackRunStart)
            )

            let fallbackRecoveryStart = CFAbsoluteTimeGetCurrent()
            if await waitForTrackingRecovery(timeout: trackingTimeout) {
                Self.recordHandoffStageIfNeeded(
                    path: telemetryPath,
                    stage: "trackingRecoveryFallback",
                    elapsedMs: Self.elapsedMs(since: fallbackRecoveryStart),
                    success: true
                )
                return .recoveredWithoutWorldMap
            }
            Self.recordHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "trackingRecoveryFallback",
                elapsedMs: Self.elapsedMs(since: fallbackRecoveryStart),
                success: false
            )
        }

        return .trackingDegraded
    }

    private func waitForTrackingRecoveryInBackground(
        timeout: TimeInterval,
        telemetryPath: CaptureTelemetry.CapturePath?,
        recoveryStart: CFAbsoluteTime,
        usedWorldMap: Bool,
        anchorTransform: simd_float4x4?
    ) {
        Task { [weak self] in
            guard let self else { return }

            if await self.waitForTrackingRecovery(timeout: timeout) {
                Self.recordHandoffStageIfNeeded(
                    path: telemetryPath,
                    stage: "trackingRecovery",
                    elapsedMs: Self.elapsedMs(since: recoveryStart),
                    success: true,
                    detail: "deferred=true"
                )
                return
            }

            Self.recordHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "trackingRecovery",
                elapsedMs: Self.elapsedMs(since: recoveryStart),
                success: false,
                detail: "deferred=true"
            )

            guard usedWorldMap else { return }

            Self.captureLog.warning("Deferred world map relocalization timed out — falling back without map")
            let fallbackRunStart = CFAbsoluteTimeGetCurrent()
            await self.resumeWithoutWorldMap(anchorTransform: anchorTransform)
            Self.recordHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "arResumeFallbackRun",
                elapsedMs: Self.elapsedMs(since: fallbackRunStart),
                detail: "deferred=true"
            )

            let fallbackRecoveryStart = CFAbsoluteTimeGetCurrent()
            let recovered = await self.waitForTrackingRecovery(timeout: timeout)
            Self.recordHandoffStageIfNeeded(
                path: telemetryPath,
                stage: "trackingRecoveryFallback",
                elapsedMs: Self.elapsedMs(since: fallbackRecoveryStart),
                success: recovered,
                detail: "deferred=true"
            )
        }
    }

    func clearHandoffFrozenPreview() {
        DispatchQueue.main.async { [weak self] in
            self?.handoffFrozenPreviewImage = nil
        }
    }

    private func buildHandoffSnapshotOnSessionQueue(
        aspectRatio: AspectRatioMode,
        worldMap: ARWorldMap?
    ) -> CaptureHandoffSnapshot {
        arStateLock.lock()
        let anchorTransform = subjectAnchor?.transform
        let orientation = sessionInterfaceOrientation
        arStateLock.unlock()

        let controls = CameraControlSnapshot.fromSpatialEngine(
            self,
            displayMultiplier: displayMultiplier
        )

        var frozenImage: UIImage?
        if let frame = session.currentFrame {
            let imageOrientation = Self.imageOrientation(for: orientation)
            frozenImage = Self.makeUIImage(from: frame.capturedImage, orientation: imageOrientation)
        }

        return CaptureHandoffSnapshot(
            worldMap: worldMap,
            subjectAnchorTransform: anchorTransform,
            cameraControls: controls,
            aspectRatio: aspectRatio,
            frozenPreviewImage: frozenImage
        )
    }

    /// Builds an anchor for post-handoff resume without adding it before `session.run`.
    private func prepareSubjectAnchorForResume(from transform: simd_float4x4?) -> ARAnchor? {
        arStateLock.lock()
        subjectAnchor = nil
        isSubjectLocked = transform != nil
        arStateLock.unlock()

        guard let transform else { return nil }
        let anchor = ARAnchor(transform: transform)
        arStateLock.lock()
        subjectAnchor = anchor
        arStateLock.unlock()
        return anchor
    }

    private func resumeWithoutWorldMap(anchorTransform: simd_float4x4?) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                let anchor = self.prepareSubjectAnchorForResume(from: anchorTransform)
                self.sessionController.runAfterHandoffWithoutWorldMap(reattach: anchor)
                self.consecutiveNormalFrames = 0
                DispatchQueue.main.async { self.trackingStabilityProgress = 0 }
                continuation.resume()
            }
        }
    }

    private func waitForTrackingRecovery(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let ready = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                sessionQueue.async { [weak self] in
                    continuation.resume(returning: self?.isTrackingReadyForCapture() ?? false)
                }
            }
            if ready { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    private static func recordHandoffStageIfNeeded(
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

    private static func elapsedMs(since start: CFAbsoluteTime) -> Int {
        Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    }

    // MARK: - High-Resolution Capture

    func captureHighResolutionPhoto(aspectRatio: AspectRatioMode) async {
        guard !isCapturingHighResolution else { return }

        await MainActor.run {
            isCapturingHighResolution = true
            capturedImage = nil
            capturedPhotoData = nil
            captureError = nil
            lastCaptureARErrorCode = nil
            pendingAspectRatio = aspectRatio
        }

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self, let config = self.worldConfiguration else {
                    Task { @MainActor in
                        self?.isCapturingHighResolution = false
                        self?.captureError = "Camera is not ready."
                    }
                    continuation.resume()
                    return
                }

                self.arStateLock.lock()
                self.isVisionPausedForCapture = true
                self.arStateLock.unlock()

                self.performHighResolutionCapture(
                    config: config,
                    retryOnBusy: true,
                    retryOnFailed: true,
                    continuation: continuation
                )
            }
        }
    }

    private func performHighResolutionCapture(
        config: ARWorldTrackingConfiguration,
        retryOnBusy: Bool,
        retryOnFailed: Bool,
        continuation: CheckedContinuation<Void, Never>
    ) {
        sessionCaptureActive = true

        guard isTrackingReadyForCapture() else {
            Self.captureLog.warning(
                "Capture blocked: tracking not ready state=\(String(describing: self.session.currentFrame?.camera.trackingState)) frames=\(self.consecutiveNormalFrames)"
            )
            sessionCaptureActive = false
            Task { @MainActor in
                self.isCapturingHighResolution = false
                self.captureError = "Hold steady until tracking is stable, then try again."
            }
            arStateLock.lock()
            isVisionPausedForCapture = false
            arStateLock.unlock()
            self.finishCaptureIfRecoveryPending()
            continuation.resume()
            return
        }

        if !config.videoFormat.isRecommendedForHighResolutionFrameCapturing {
            Self.captureLog.warning("Video format not recommended for hi-res capture")
        }

        let photoSettings = config.videoFormat.defaultPhotoSettings

        arStateLock.lock()
        let captureOrientation = sessionInterfaceOrientation
        let captureRatio = pendingAspectRatio
        let captureFlash = flashMode
        let capturePreviewScale = CaptureZoomRouting.effectivePreviewScale(for: displayMultiplier)
        arStateLock.unlock()

        let settings = photoSettings
        settings.photoQualityPrioritization = .balanced
        settings.flashMode = captureFlash

        session.captureHighResolutionFrame(using: settings) { [weak self] frame, error in
            guard let self else {
                continuation.resume()
                return
            }

            if let error {
                if retryOnBusy,
                   let arError = error as? ARError,
                   arError.code == .highResolutionFrameCaptureInProgress {
                    self.sessionQueue.asyncAfter(deadline: .now() + 0.5) {
                        self.performHighResolutionCapture(
                            config: config,
                            retryOnBusy: false,
                            retryOnFailed: retryOnFailed,
                            continuation: continuation
                        )
                    }
                    return
                }

                if retryOnFailed,
                   let arError = error as? ARError,
                   arError.code == .highResolutionFrameCaptureFailed,
                   self.isTrackingReadyForCapture() {
                    Self.logCaptureFailure(error: error, config: config)
                    self.sessionQueue.asyncAfter(deadline: .now() + 0.5) {
                        self.performHighResolutionCapture(
                            config: config,
                            retryOnBusy: false,
                            retryOnFailed: false,
                            continuation: continuation
                        )
                    }
                    return
                }

                Self.logCaptureFailure(error: error, config: config)
                let message = Self.captureErrorMessage(for: error)
                let arCode = (error as? ARError)?.code.rawValue
                Task { @MainActor in
                    self.isCapturingHighResolution = false
                    self.captureError = message
                    self.lastCaptureARErrorCode = arCode
                }
                self.arStateLock.lock()
                self.isVisionPausedForCapture = false
                self.arStateLock.unlock()
                self.sessionCaptureActive = false
                self.finishCaptureIfRecoveryPending()
                continuation.resume()
                return
            }

            guard let frame else {
                Task { @MainActor in
                    self.isCapturingHighResolution = false
                    self.captureError = "Photo capture returned no image."
                }
                self.arStateLock.lock()
                self.isVisionPausedForCapture = false
                self.arStateLock.unlock()
                self.sessionCaptureActive = false
                self.finishCaptureIfRecoveryPending()
                continuation.resume()
                return
            }

            let orientation = Self.imageOrientation(for: captureOrientation)
            let pixelBuffer = frame.capturedImage

            DispatchQueue.global(qos: .userInitiated).async {
                let image = Self.makeUIImage(from: pixelBuffer, orientation: orientation)
                let jpegData = image.flatMap {
                    Self.makeJPEGData(
                        from: $0,
                        aspectRatio: captureRatio,
                        previewScale: capturePreviewScale
                    )
                } ?? image?.jpegData(compressionQuality: 0.95)

                Task { @MainActor in
                    self.isCapturingHighResolution = false
                    if let image {
                        self.capturedImage = image
                        self.capturedPhotoData = jpegData
                    } else {
                        self.captureError = "Could not process captured image."
                    }
                    continuation.resume()
                }
                self.arStateLock.lock()
                self.isVisionPausedForCapture = false
                self.arStateLock.unlock()
                self.sessionCaptureActive = false
                self.finishCaptureIfRecoveryPending()
            }
        }
    }

    private func finishCaptureIfRecoveryPending() {
        guard pendingSessionRecovery else { return }
        pendingSessionRecovery = false
        configureAndRun(resetAnchors: false)
    }

    private func isTrackingReadyForCapture() -> Bool {
        guard let frame = session.currentFrame else { return false }
        guard case .normal = frame.camera.trackingState else { return false }
        return consecutiveNormalFrames >= Self.requiredNormalFramesForCapture
    }

    private static func logCaptureFailure(error: Error, config: ARWorldTrackingConfiguration) {
        let thermal = ProcessInfo.processInfo.thermalState.rawValue
        let hiResOK = config.videoFormat.isRecommendedForHighResolutionFrameCapturing
        if let arError = error as? ARError {
            captureLog.error("Capture failed code=\(arError.code.rawValue) thermal=\(thermal) hiResFormat=\(hiResOK)")
        } else {
            captureLog.error("Capture failed thermal=\(thermal) hiResFormat=\(hiResOK) error=\(error.localizedDescription)")
        }
    }

    private static func imageOrientation(for interfaceOrientation: UIInterfaceOrientation) -> UIImage.Orientation {
        switch interfaceOrientation {
        case .portrait: return .right
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        default: return .right
        }
    }

    private static func makeUIImage(from pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = captureCIContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    private static func captureErrorMessage(for error: Error) -> String {
        if let arError = error as? ARError {
            switch arError.code {
            case .highResolutionFrameCaptureInProgress:
                return "Please wait — a photo is still being captured."
            case .highResolutionFrameCaptureFailed:
                return error.localizedDescription
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private static func makeJPEGData(
        from image: UIImage,
        aspectRatio: AspectRatioMode,
        previewScale: CGFloat = 1.0
    ) -> Data? {
        guard let cgImage = image.cgImage else {
            return image.jpegData(compressionQuality: 0.95)
        }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var cropRect = CGRect(x: 0, y: 0, width: width, height: height)

        if previewScale > 1.01 {
            let fraction = max(1.0 / previewScale, 0.1)
            let cropWidth = width * fraction
            let cropHeight = height * fraction
            cropRect = CGRect(
                x: (width - cropWidth) / 2,
                y: (height - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
        }

        if aspectRatio != .free {
            let cw = cropRect.width
            let ch = cropRect.height
            switch aspectRatio {
            case .oneOne:
                let side = min(cw, ch)
                cropRect = CGRect(x: cropRect.minX + (cw - side) / 2, y: cropRect.minY + (ch - side) / 2, width: side, height: side)
            case .sixteenNine:
                let targetHeight = cw * (16.0 / 9.0)
                if targetHeight <= ch {
                    cropRect = CGRect(x: cropRect.minX, y: cropRect.minY + (ch - targetHeight) / 2, width: cw, height: targetHeight)
                } else {
                    let targetWidth = ch * (9.0 / 16.0)
                    cropRect = CGRect(x: cropRect.minX + (cw - targetWidth) / 2, y: cropRect.minY, width: targetWidth, height: ch)
                }
            case .fourThree:
                let targetHeight = cw * (4.0 / 3.0)
                if targetHeight <= ch {
                    cropRect = CGRect(x: cropRect.minX, y: cropRect.minY + (ch - targetHeight) / 2, width: cw, height: targetHeight)
                } else {
                    let targetWidth = ch * (3.0 / 4.0)
                    cropRect = CGRect(x: cropRect.minX + (cw - targetWidth) / 2, y: cropRect.minY, width: targetWidth, height: ch)
                }
            case .free: break
            }
        }
        
        if cropRect.width < width || cropRect.height < height {
            if let croppedCGImage = cgImage.cropping(to: cropRect) {
                let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                return croppedUIImage.jpegData(compressionQuality: 0.95)
            }
        }

        return image.jpegData(compressionQuality: 0.95)
    }

    /// Builds a packet synchronously while `frame` is valid. Copies the pixel buffer only when Vision is ready.
    private func makeFramePacket(from frame: ARFrame) -> SpatialFramePacket {
        arStateLock.lock()
        let viewport = sessionViewportSize
        let orientation = sessionInterfaceOrientation
        arStateLock.unlock()

        let projected = projectedSubjectPoint(for: frame)

        arStateLock.lock()
        let visionPaused = isVisionPausedForCapture
        arStateLock.unlock()

        let trackingNormal: Bool
        if case .normal = frame.camera.trackingState {
            trackingNormal = true
        } else {
            trackingNormal = false
        }

        visionFrameProcessCounter += 1
        let visionInterval = Self.visionFrameInterval()
        let shouldRunVision = !visionPaused
            && trackingNormal
            && (visionFrameProcessCounter % visionInterval == 0)
            && (shouldProcessVisionFrame?() ?? true)

        let copiedBuffer: CVPixelBuffer?
        if shouldRunVision {
            copiedBuffer = PixelBufferCopier.copy(frame.capturedImage)
        } else {
            copiedBuffer = nil
        }

        return SpatialFramePacket(
            pixelBuffer: copiedBuffer,
            spatialSubjectPoint: projected,
            viewportSize: viewport,
            interfaceOrientation: orientation
        )
    }

    /// Runs synchronously inside the ARSession delegate before `frame` is released.
    private func handleFrameUpdate(_ frame: ARFrame) {
        arStateLock.lock()
        let pending = pendingLockPoint
        arStateLock.unlock()

        if let pending {
            performLock(at: pending, frame: frame)
        }

        let tracking = frame.camera.trackingState
        if case .normal = tracking {
            consecutiveNormalFrames = min(consecutiveNormalFrames + 1, Self.requiredNormalFramesForCapture + 1)
        } else {
            consecutiveNormalFrames = 0
        }

        let progress: Float = {
            guard case .normal = tracking else { return 0 }
            return min(1, Float(consecutiveNormalFrames) / Float(Self.requiredNormalFramesForCapture))
        }()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.trackingState = tracking
            self.trackingStabilityProgress = progress
            self.onTrackingStateChanged?(tracking)
        }

        let packet = makeFramePacket(from: frame)
        onFrameUpdated?(packet)
    }
}

// MARK: - ARSessionDelegate

extension SpatialCameraEngine: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Extract all frame-dependent data synchronously — ARFrame must not outlive this callback.
        handleFrameUpdate(frame)
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.sessionCaptureActive {
                self.pendingSessionRecovery = true
                return
            }
            self.configureAndRun(resetAnchors: false)
        }
    }
}
