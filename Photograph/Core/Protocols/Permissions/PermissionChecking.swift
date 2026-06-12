//
//  PermissionChecking.swift
//  Photograph
//

import Foundation

/// Camera and photo-library permission queries and requests.
protocol PermissionChecking: Sendable {
    func cameraStatus() -> PermissionStatus
    func photoAddStatus() -> PermissionStatus
    func photoReadStatus() -> PermissionStatus
    func requestCameraAccess() async -> PermissionStatus
    func requestPhotoAddAccess() async -> PermissionStatus
    func requestPhotoReadAccess() async -> PermissionStatus
}
