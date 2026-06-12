//
//  CameraPermissionGateView.swift
//  Visula
//
//  Shown when camera access is not granted (denied, restricted, or first launch).
//

import SwiftUI

struct CameraPermissionGateView: View {
    let status: PermissionStatus
    let isRequesting: Bool
    let onRequestAccess: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            AppColors.surface.ignoresSafeArea()

            VStack(spacing: Spacing.medium) {
                Image(systemName: iconName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AppColors.controlActive)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.textOnCamera)
                    .multilineTextAlignment(.center)

                Text(PrivacyPermissionService.cameraGateMessage(for: status))
                    .font(.body)
                    .foregroundStyle(AppColors.textGuide)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.large)

                primaryAction
                    .padding(.top, Spacing.small)
            }
            .padding(Spacing.large)
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch status {
        case .notDetermined: return "Camera Access"
        case .denied: return "Camera Access Needed"
        case .restricted: return "Camera Unavailable"
        case .authorized, .limited: return ""
        }
    }

    private var iconName: String {
        switch status {
        case .restricted: return "lock.fill"
        case .denied: return "camera.fill"
        default: return "camera.viewfinder"
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if status.needsSettings {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
        } else {
            Button {
                onRequestAccess()
            } label: {
                if isRequesting {
                    ProgressView()
                        .tint(AppColors.textOnCamera)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
            .disabled(isRequesting)
        }
    }
}
