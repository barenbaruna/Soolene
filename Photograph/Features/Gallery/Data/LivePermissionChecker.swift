//
//  LivePermissionChecker.swift
//  Photograph
//

import Foundation

/// Default `PermissionChecking` backed by `PrivacyPermissionService`.
struct LivePermissionChecker: PermissionChecking {
    @MainActor
    func cameraStatus() -> PermissionStatus {
        PrivacyPermissionService.cameraStatus()
    }

    @MainActor
    func photoAddStatus() -> PermissionStatus {
        PrivacyPermissionService.photoAddStatus()
    }

    @MainActor
    func photoReadStatus() -> PermissionStatus {
        PrivacyPermissionService.photoReadStatus()
    }

    @MainActor
    func requestCameraAccess() async -> PermissionStatus {
        await PrivacyPermissionService.requestCameraAccess()
    }

    @MainActor
    func requestPhotoAddAccess() async -> PermissionStatus {
        await PrivacyPermissionService.requestPhotoAddAccess()
    }

    @MainActor
    func requestPhotoReadAccess() async -> PermissionStatus {
        await PrivacyPermissionService.requestPhotoReadAccess()
    }
}
