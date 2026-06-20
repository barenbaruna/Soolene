//
//  AppDependencies.swift
//  Soolene
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

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel()
    }

    func makeGalleryViewModel() -> GalleryViewModel {
        GalleryViewModel(gallery: gallery, permissions: permissions)
    }

    func makeCompositionPhotoListViewModel(composition: CompositionType) -> CompositionPhotoListViewModel {
        CompositionPhotoListViewModel(composition: composition, gallery: gallery)
    }
}
