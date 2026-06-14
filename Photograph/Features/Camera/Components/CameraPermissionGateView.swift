//
//  CameraPermissionGateView.swift
//  Visula
//
//  Shown before the camera starts when required permissions are missing.
//

import SwiftUI

struct CameraPermissionGateView: View {
    let cameraStatus: PermissionStatus
    let photoStatus: PermissionStatus
    let isRequestingCamera: Bool
    let isRequestingPhoto: Bool
    let onRequestCameraAccess: () -> Void
    let onRequestPhotoAccess: () -> Void
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            AppColors.permissionSurface.ignoresSafeArea()

            VStack(spacing: Spacing.large) {
                VStack(spacing: Spacing.standard) {
                    Image(systemName: "checklist")
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)

                    VStack(spacing: Spacing.small) {
                        Text("Permissions")
                            .font(Typography.title)
                            .foregroundStyle(AppColors.permissionTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("\(AppIdentity.displayName) needs these permissions to guide your shots and keep your photos in one place.")
                            .font(Typography.body)
                            .foregroundStyle(AppColors.permissionTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 0) {
                    permissionRow(
                        title: "Camera",
                        message: "We need camera access to show the live viewfinder and composition guidance while you shoot.",
                        systemImage: "camera.viewfinder",
                        status: cameraStatus,
                        isAllowed: cameraStatus.allowsCamera
                    )

                    Divider()
                        .background(AppColors.permissionDivider)
                        .padding(.leading, 58)

                    permissionRow(
                        title: "Gallery",
                        message: "We need photo library access to save captures and show your guided compositions in Gallery.",
                        systemImage: "photo.stack",
                        status: photoStatus,
                        isAllowed: photoStatus.allowsPhotoBrowse
                    )
                }

                Button {
                    requestNextPermission()
                } label: {
                    HStack(spacing: Spacing.small) {
                        if isRequestingCurrentPermission {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(primaryActionTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .font(Typography.buttonCTA)
                .buttonStyle(.borderedProminent)
                .tint(primaryActionTint)
                .disabled(isRequestingCurrentPermission)
                .controlSize(.large)
                .padding(.top, Spacing.small)
            }
            .frame(maxWidth: 430)
            .padding(Spacing.large)
        }
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
    }

    private var primaryActionTitle: String {
        if !cameraStatus.allowsCamera {
            return cameraStatus.needsSettings ? "Review Camera Access" : "Allow Camera"
        }

        if !photoStatus.allowsPhotoBrowse {
            return photoStatus.needsSettings ? "Review Gallery Access" : "Allow Gallery Access"
        }

        return "Completed"
    }

    private var primaryActionTint: Color {
        cameraStatus.allowsCamera && photoStatus.allowsPhotoBrowse ? AppColors.secondary : AppColors.primary
    }

    private var isRequestingCurrentPermission: Bool {
        if !cameraStatus.allowsCamera {
            return isRequestingCamera
        }
        if !photoStatus.allowsPhotoBrowse {
            return isRequestingPhoto
        }
        return false
    }

    private func requestNextPermission() {
        if !cameraStatus.allowsCamera {
            onRequestCameraAccess()
        } else if !photoStatus.allowsPhotoBrowse {
            onRequestPhotoAccess()
        } else {
            onComplete()
        }
    }

    private func permissionRow(
        title: String,
        message: String,
        systemImage: String,
        status: PermissionStatus,
        isAllowed: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.standard) {
            Image(systemName: isAllowed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isAllowed ? AppColors.primary : AppColors.permissionIconInactive)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Label(title, systemImage: systemImage)
                        .font(Typography.headline)
                        .foregroundStyle(AppColors.permissionTextPrimary)
                        .labelStyle(.titleAndIcon)

                    Spacer(minLength: Spacing.small)

                    Text(statusLabel(for: status, isAllowed: isAllowed))
                        .font(Typography.caption)
                        .foregroundStyle(isAllowed ? AppColors.primary : AppColors.permissionTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text(message)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColors.permissionTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.standard)
        .accessibilityElement(children: .combine)
    }

    private func statusLabel(for status: PermissionStatus, isAllowed: Bool) -> String {
        if isAllowed {
            return status == .limited ? "Limited" : "Allowed"
        }

        if status.needsSettings {
            return "Needs Settings"
        }

        return "Required"
    }
}

#Preview("Permissions") {
    CameraPermissionGateView(
        cameraStatus: .notDetermined,
        photoStatus: .notDetermined,
        isRequestingCamera: false,
        isRequestingPhoto: false,
        onRequestCameraAccess: {},
        onRequestPhotoAccess: {},
        onComplete: {}
    )
}

#Preview("Camera Allowed") {
    CameraPermissionGateView(
        cameraStatus: .authorized,
        photoStatus: .denied,
        isRequestingCamera: false,
        isRequestingPhoto: false,
        onRequestCameraAccess: {},
        onRequestPhotoAccess: {},
        onComplete: {}
    )
}

#Preview("Completed") {
    CameraPermissionGateView(
        cameraStatus: .authorized,
        photoStatus: .authorized,
        isRequestingCamera: false,
        isRequestingPhoto: false,
        onRequestCameraAccess: {},
        onRequestPhotoAccess: {},
        onComplete: {}
    )
}
