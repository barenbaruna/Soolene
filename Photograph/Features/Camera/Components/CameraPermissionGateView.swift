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

                VStack(spacing: Spacing.small) {
                    permissionActionCard(
                        title: "Camera",
                        message: "We need camera access to show the live viewfinder and composition guidance while you shoot.",
                        systemImage: "camera.viewfinder",
                        status: cameraStatus,
                        isAllowed: cameraStatus.allowsCamera,
                        isRequesting: isRequestingCamera,
                        action: onRequestCameraAccess
                    )

                    permissionActionCard(
                        title: "Gallery",
                        message: "We need photo library access to save captures and show your guided compositions in Gallery.",
                        systemImage: "photo.stack",
                        status: photoStatus,
                        isAllowed: photoStatus.allowsPhotoBrowse,
                        isRequesting: isRequestingPhoto,
                        action: onRequestPhotoAccess
                    )
                }

                Text("\(completedPermissionCount) of 2 permissions ready")
                    .font(Typography.caption)
                    .foregroundStyle(AppColors.permissionTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        .accessibilityElement(children: .contain)
    }

    private var primaryActionTitle: String {
        if !cameraStatus.allowsCamera {
            return cameraStatus.needsSettings ? "Review Camera Access" : "Allow Camera"
        }

        if !photoStatus.allowsPhotoBrowse {
            return photoStatus.needsSettings ? "Review Gallery Access" : "Allow Gallery Access"
        }

        return "Continue"
    }

    private var primaryActionTint: Color {
        cameraStatus.allowsCamera && photoStatus.allowsPhotoBrowse ? AppColors.primary : AppColors.secondary
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

    private var completedPermissionCount: Int {
        [cameraStatus.allowsCamera, photoStatus.allowsPhotoBrowse].filter(\.self).count
    }

    @ViewBuilder
    private func permissionActionCard(
        title: String,
        message: String,
        systemImage: String,
        status: PermissionStatus,
        isAllowed: Bool,
        isRequesting: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if isAllowed {
            permissionCardContent(
                title: title,
                message: message,
                systemImage: systemImage,
                status: status,
                isAllowed: true,
                isRequesting: false
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: title, status: status, isAllowed: true, isRequesting: false))
        } else {
            Button(action: action) {
                permissionCardContent(
                    title: title,
                    message: message,
                    systemImage: systemImage,
                    status: status,
                    isAllowed: false,
                    isRequesting: isRequesting
                )
            }
            .buttonStyle(.plain)
            .disabled(isRequestingCurrentPermission)
            .accessibilityLabel(accessibilityLabel(for: title, status: status, isAllowed: false, isRequesting: isRequesting))
        }
    }

    private func permissionCardContent(
        title: String,
        message: String,
        systemImage: String,
        status: PermissionStatus,
        isAllowed: Bool,
        isRequesting: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.standard) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(isAllowed ? AppColors.primary : AppColors.permissionTextPrimary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isAllowed ? AppColors.primary.opacity(0.12) : AppColors.permissionIconInactive.opacity(0.16))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(title)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColors.permissionTextPrimary)

                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(AppColors.permissionTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.small)

            permissionStatusIndicator(status: status, isAllowed: isAllowed, isRequesting: isRequesting)
        }
        .padding(Spacing.standard)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(Color.white.opacity(isAllowed ? 0.78 : 0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isAllowed ? AppColors.primary.opacity(0.28) : AppColors.permissionDivider, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    @ViewBuilder
    private func permissionStatusIndicator(
        status: PermissionStatus,
        isAllowed: Bool,
        isRequesting: Bool
    ) -> some View {
        if isRequesting {
            ProgressView()
                .tint(AppColors.primary)
                .accessibilityHidden(true)
        } else if isAllowed {
            HStack(spacing: Spacing.tiny) {
                Image(systemName: "checkmark.circle.fill")
                Text(statusLabel(for: status, isAllowed: true))
            }
            .font(Typography.caption)
            .foregroundStyle(AppColors.primary)
            .lineLimit(1)
        } else {
            HStack(spacing: Spacing.tiny) {
                Text(actionLabel(for: status))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .font(Typography.caption)
            .foregroundStyle(AppColors.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
    }

    private func actionLabel(for status: PermissionStatus) -> String {
        status.needsSettings ? "Review" : "Allow"
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

    private func accessibilityLabel(
        for title: String,
        status: PermissionStatus,
        isAllowed: Bool,
        isRequesting: Bool
    ) -> String {
        if isRequesting {
            return "\(title), requesting access"
        }

        if isAllowed {
            return "\(title), \(statusLabel(for: status, isAllowed: true).lowercased())"
        }

        if status.needsSettings {
            return "\(title), needs settings, review \(title.lowercased()) access"
        }

        return "\(title), required, allow \(title.lowercased()) access"
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
        photoStatus: .notDetermined,
        isRequestingCamera: false,
        isRequestingPhoto: false,
        onRequestCameraAccess: {},
        onRequestPhotoAccess: {},
        onComplete: {}
    )
}

#Preview("Camera Denied") {
    CameraPermissionGateView(
        cameraStatus: .denied,
        photoStatus: .notDetermined,
        isRequestingCamera: false,
        isRequestingPhoto: false,
        onRequestCameraAccess: {},
        onRequestPhotoAccess: {},
        onComplete: {}
    )
}

#Preview("Gallery Denied") {
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

#Preview("Gallery Limited") {
    CameraPermissionGateView(
        cameraStatus: .authorized,
        photoStatus: .limited,
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
