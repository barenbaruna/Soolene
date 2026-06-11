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
    var trackingState: ARCamera.TrackingState = .notAvailable
    var isCapturingHighResolution = false
    var lastLockQuality: SubjectLockQuality?
    var viewportSize: CGSize = .zero

    /// The processed preview is driven by ARSCNView bound to `session`.
    let session = ARSession()

    // MARK: - Callbacks

    var onFrameUpdated: (@Sendable (SpatialFramePacket) -> Void)?
    var onSubjectLockResult: (@Sendable (SubjectLockQuality?) -> Void)?
    /// When false, the delegate skips pixel-buffer copy (Vision still receives projected subject).
    var shouldProcessVisionFrame: (@Sendable () -> Bool)?

    // MARK: - Private

    private let sessionQueue = DispatchQueue(label: "com.photograph.arSession", qos: .userInitiated)
    private let arStateLock = NSLock()
    private var worldConfiguration: ARWorldTrackingConfiguration?
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

    private static let captureCIContext = CIContext(options: nil)
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
        guard ARWorldTrackingConfiguration.isSupported else { return }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.isAutoFocusEnabled = true
        config.worldAlignment = .gravity

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        if let recommended = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
            config.videoFormat = recommended
        } else if let hiResFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: {
            $0.isRecommendedForHighResolutionFrameCapturing
        }) {
            config.videoFormat = hiResFormat
        }

        configureContinuousAutoFocus()

        worldConfiguration = config
        let options: ARSession.RunOptions = resetAnchors ? [.resetTracking, .removeExistingAnchors] : [.resetTracking]
        session.run(config, options: options)

        if !resetAnchors, let anchor = subjectAnchor {
            session.add(anchor: anchor)
        } else if resetAnchors {
            subjectAnchor = nil
            isSubjectLocked = false
        }

        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = true
            self?.isARKitSupported = true
            self?.isSessionConfigured = true
        }
    }

    /// Resumes an existing configuration without resetting world anchors.
    func resumeSessionPreservingAnchors() {
        sessionQueue.async { [weak self] in
            guard let self, let config = self.worldConfiguration else { return }
            self.session.run(config)
            DispatchQueue.main.async {
                self.isSessionRunning = true
                self.isSessionConfigured = true
            }
        }
    }

    private func configureContinuousAutoFocus() {
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // Non-fatal — ARKit still runs with default focus.
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.worldConfiguration == nil {
                self.configureAndRun(resetAnchors: true)
            } else if let config = self.worldConfiguration {
                self.session.run(config)
                DispatchQueue.main.async { self.isSessionRunning = true }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.pause()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }

    /// Pauses the AR session and waits until the session queue has finished.
    func stopSessionAndWait() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                self?.session.pause()
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

        if let depthMeters = sceneDepth(at: imagePoint, frame: frame) {
            let transform = worldTransform(
                for: imagePoint,
                distanceMeters: depthMeters,
                frame: frame
            )
            installAnchor(at: transform, quality: .depthPlacement)
            return
        }

        let fallbackDistance: Float = 1.5
        let transform = worldTransform(
            for: imagePoint,
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

    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }

            do {
                try device.lockForConfiguration()
                let clamped = min(
                    max(factor, device.minAvailableVideoZoomFactor),
                    min(device.maxAvailableVideoZoomFactor, 10)
                )
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                // Ignore transient configuration failures.
            }
        }
    }

    var maximumZoomFactor: CGFloat {
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return 1 }
        return min(device.maxAvailableVideoZoomFactor, 10)
    }

    func cycleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    // MARK: - High-Resolution Capture

    func captureHighResolutionPhoto(aspectRatio: AspectRatioMode) async {
        guard !isCapturingHighResolution else { return }

        await MainActor.run {
            isCapturingHighResolution = true
            capturedImage = nil
            capturedPhotoData = nil
            captureError = nil
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
        arStateLock.unlock()

        var settings = photoSettings
        settings.photoQualityPrioritization = .quality
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
                Task { @MainActor in
                    self.isCapturingHighResolution = false
                    self.captureError = message
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
                let jpegData = image.flatMap { Self.makeJPEGData(from: $0, aspectRatio: captureRatio) }
                    ?? image?.jpegData(compressionQuality: 0.95)

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
                return "Photo capture failed. Hold steady until tracking is stable, then try again."
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private static func makeJPEGData(from image: UIImage, aspectRatio: AspectRatioMode) -> Data? {
        guard let baseData = image.jpegData(compressionQuality: 0.95) else { return nil }
        return ImageCropHelper.cropImageWithMetadata(imageData: baseData, ratio: aspectRatio) ?? baseData
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

        DispatchQueue.main.async { [weak self] in
            self?.trackingState = tracking
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
