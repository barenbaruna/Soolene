//
//  CameraSessionCoordinator.swift
//  Photograph
//
//  Serializes rear/front camera handoff and session lifecycle.
//

import AVFoundation

@MainActor
final class CameraSessionCoordinator {

    private let spatialEngine: SpatialCameraEngine
    private let cameraManager: CameraManager
    private let visionService: VisionService

    var onGuidanceReset: (() -> Void)?
    var onPreviewReady: (() -> Void)?

    init(
        spatialEngine: SpatialCameraEngine,
        cameraManager: CameraManager,
        visionService: VisionService
    ) {
        self.spatialEngine = spatialEngine
        self.cameraManager = cameraManager
        self.visionService = visionService
    }

    func switchToFrontClassic(hasCameraPermission: Bool, checkPermissions: () async -> Void) async {
        await spatialEngine.stopSessionAndWait()
        spatialEngine.clearSubjectAnchor()
        onGuidanceReset?()

        visionService.usesSpatialTracking = false
        visionService.isFrontCamera = true
        visionService.isMLEnabled = true

        if !hasCameraPermission {
            await checkPermissions()
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let lock = NSLock()
            var resumed = false

            func resumeOnce() {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }

            cameraManager.onPreviewFrameReady = { @Sendable in
                Task { @MainActor in
                    resumeOnce()
                }
            }

            cameraManager.sessionQueue.async { [cameraManager] in
                cameraManager.configureSession(useFront: true, lens: .wide)
                cameraManager.startSession()
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                resumeOnce()
            }
        }

        cameraManager.onPreviewFrameReady = nil
        onPreviewReady?()
    }

    func switchToRearSpatial() async {
        await cameraManager.stopSessionAndWait()
        onGuidanceReset?()

        visionService.usesSpatialTracking = true
        visionService.isFrontCamera = false
        visionService.isMLEnabled = true

        await spatialEngine.checkPermissionsAndSetup()
    }

    func pauseSessions(cameraMode: CameraMode) {
        spatialEngine.stopSession()
        cameraManager.stopSession()
    }

    func resumeSession(cameraMode: CameraMode) {
        switch cameraMode {
        case .rearSpatial:
            spatialEngine.resumeSessionPreservingAnchors()
        case .frontClassic:
            cameraManager.startSession()
        }
    }
}
