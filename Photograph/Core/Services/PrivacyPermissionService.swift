//
//  PrivacyPermissionService.swift
//  Visula
//
//  Camera and Photo Library permission status, requests, and Settings deep link.
//

import AVFoundation
import Photos
import PhotosUI
import UIKit

enum PermissionStatus: Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    var allowsCamera: Bool {
        self == .authorized
    }

    var allowsPhotoSave: Bool {
        self == .authorized || self == .limited
    }

    var allowsPhotoBrowse: Bool {
        self == .authorized || self == .limited
    }

    var needsSettings: Bool {
        self == .denied || self == .restricted
    }
}

@MainActor
enum PrivacyPermissionService {

    static func cameraStatus() -> PermissionStatus {
        map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    static func photoAddStatus() -> PermissionStatus {
        map(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    static func photoReadStatus() -> PermissionStatus {
        map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    static func requestCameraAccess() async -> PermissionStatus {
        let current = cameraStatus()
        guard current == .notDetermined else { return current }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    static func requestPhotoAddAccess() async -> PermissionStatus {
        let current = photoAddStatus()
        guard current == .notDetermined else { return current }
        return map(await PHPhotoLibrary.requestAuthorization(for: .addOnly))
    }

    static func requestPhotoReadAccess() async -> PermissionStatus {
        let current = photoReadStatus()
        guard current == .notDetermined else { return current }
        return map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    static func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let controller = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    static func cameraGateMessage(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Allow \(AppIdentity.displayName) to use your camera for live composition guidance."
        case .denied:
            return "\(AppIdentity.displayName) needs camera access. Enable Camera in Settings to continue."
        case .restricted:
            return "Camera access is restricted on this device. Check Screen Time or device management settings."
        case .authorized, .limited:
            return ""
        }
    }

    static func photoSaveMessage(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Allow \(AppIdentity.displayName) to save photos to your library."
        case .denied:
            return "Photo access denied. Enable Photos for \(AppIdentity.displayName) in Settings to save captures."
        case .restricted:
            return "Photo Library access is restricted on this device."
        case .limited:
            return "\(AppIdentity.displayName) can save new photos. Library browsing is limited to photos you select."
        case .authorized:
            return ""
        }
    }

    static func photoBrowseMessage(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Allow \(AppIdentity.displayName) to show your saved photos in Gallery."
        case .denied:
            return "\(AppIdentity.displayName) needs Gallery access. Enable Photos in Settings to continue."
        case .restricted:
            return "Gallery access is restricted on this device. Check Screen Time or device management settings."
        case .limited:
            return "Limited Gallery access - \(AppIdentity.displayName) can only show photos you have selected. Tap Manage to grant more."
        case .authorized:
            return ""
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}
