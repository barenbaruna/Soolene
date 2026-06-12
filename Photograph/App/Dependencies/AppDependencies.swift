//
//  AppDependencies.swift
//  Photograph
//
//  Composition root for feature ViewModels. Existing code may still construct
//  services directly until migration completes.
//

import Foundation

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let spatialCamera: SpatialCameraProviding
    let classicCamera: ClassicCameraProviding
    let vision: VisionAnalyzing
    let gallery: GalleryRepository
    let permissions: PermissionChecking

    private init() {
        let spatial = SpatialCameraEngine()
        let classic = CameraManager()
        let visionService = VisionService()

        self.spatialCamera = spatial
        self.classicCamera = classic
        self.vision = visionService
        self.gallery = LiveGalleryRepository()
        self.permissions = LivePermissionChecker()

        visionService.usesSpatialTracking = true
    }

    /// Factory for the camera screen. Coordinators are created inside the ViewModel today.
    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel()
    }
}
