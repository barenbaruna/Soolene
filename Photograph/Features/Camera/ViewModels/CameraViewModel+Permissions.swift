//
//  CameraViewModel+Permissions.swift
//  Photograph
//

import Foundation

extension CameraViewModel {

    func refreshPermissions() async {
        cameraPermission = PrivacyPermissionService.cameraStatus()
        photoAddPermission = PrivacyPermissionService.photoAddStatus()
        photoReadPermission = PrivacyPermissionService.photoReadStatus()
    }

    func requestCameraAccess() async {
        isRequestingCameraPermission = true
        defer { isRequestingCameraPermission = false }
        cameraPermission = await PrivacyPermissionService.requestCameraAccess()
        if cameraPermission.allowsCamera {
            await spatialEngine.checkPermissionsAndSetup()
        }
    }

    func requestPhotoAddAccess() async {
        isRequestingPhotoPermission = true
        defer { isRequestingPhotoPermission = false }
        photoAddPermission = await PrivacyPermissionService.requestPhotoAddAccess()
        photoReadPermission = PrivacyPermissionService.photoReadStatus()
    }

    func openAppSettings() {
        PrivacyPermissionService.openSettings()
    }

    func presentLimitedPhotoPicker() {
        PrivacyPermissionService.presentLimitedLibraryPicker()
    }

    func checkPermissions() async {
        await refreshPermissions()
    }
}
