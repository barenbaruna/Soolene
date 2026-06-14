//
//  PhotoLibraryPermissionView.swift
//  Visula
//
//  Library gate for denied, restricted, limited, or not-determined photo access.
//

import SwiftUI

struct PhotoLibraryPermissionView: View {
    let readStatus: PermissionStatus
    let isRequesting: Bool
    let onRequestAccess: () -> Void
    let onOpenSettings: () -> Void
    let onManageLimited: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: iconName)
        } description: {
            Text(PrivacyPermissionService.photoBrowseMessage(for: readStatus))
        } actions: {
            actionButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.gallerySurface)
    }

    private var title: String {
        switch readStatus {
        case .notDetermined: return "Gallery Access"
        case .denied: return "Gallery Access Needed"
        case .restricted: return "Gallery Unavailable"
        case .limited: return "Limited Gallery Access"
        case .authorized: return ""
        }
    }

    private var iconName: String {
        switch readStatus {
        case .limited: return "photo.on.rectangle.angled"
        case .denied, .restricted: return "lock.fill"
        default: return "photo.stack"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if readStatus == .limited {
            Button("Manage Photo Access", action: onManageLimited)
            Button("Open Settings", action: onOpenSettings)
        } else if readStatus.needsSettings {
            Button("Open Settings", action: onOpenSettings)
        } else {
            Button {
                onRequestAccess()
            } label: {
                if isRequesting {
                    ProgressView()
                } else {
                    Text("Allow Access")
                }
            }
            .disabled(isRequesting)
        }
    }
}
