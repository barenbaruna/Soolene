//
//  PrivacyPermissionService.swift
//  Soolene
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
    static let cameraSettingsMessage = """
    \(AppIdentity.displayName) needs the camera to show the live viewfinder and guide your composition while you shoot. The camera is only used for this shooting experience.
    """

    static let photoLibrarySettingsMessage = """
    \(AppIdentity.displayName) needs Photo Library access to save your captures and show your guided shots in Gallery. Your photos are used only for saving and displaying them in the app.
    """

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
            return "Allow \(AppIdentity.displayName) to use your camera for the live viewfinder and composition guidance."
        case .denied:
            return cameraSettingsMessage
        case .restricted:
            return "Camera access is restricted on this device. Check Screen Time or device management settings."
        case .authorized, .limited:
            return ""
        }
    }

    static func photoSaveMessage(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Allow \(AppIdentity.displayName) to save guided captures to your Photo Library."
        case .denied:
            return photoLibrarySettingsMessage
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
            return "Allow \(AppIdentity.displayName) to show your guided shots in Gallery."
        case .denied:
            return photoLibrarySettingsMessage
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
