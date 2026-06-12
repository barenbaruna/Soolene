//
//  GalleryViewModel.swift
//  Photograph
//

import Photos
import SwiftUI

@MainActor
@Observable
final class GalleryViewModel {
    var compositionCounts: [CompositionType: Int] = [:]
    var previewAssets: [CompositionType: PHAsset] = [:]
    var recentAsset: PHAsset?
    var recentComposition: CompositionType = .ruleOfThirds
    var isLoading = true
    var readPermission: PermissionStatus = .notDetermined
    var isRequestingPermission = false

    private let gallery: GalleryRepository
    private let permissions: PermissionChecking

    init(
        gallery: GalleryRepository = LiveGalleryRepository(),
        permissions: PermissionChecking = LivePermissionChecker()
    ) {
        self.gallery = gallery
        self.permissions = permissions
    }

    var isLibraryEmpty: Bool {
        compositionCounts.values.reduce(0, +) == 0
    }

    func bootstrap() async {
        readPermission = await permissions.photoReadStatus()
        await refresh()
    }

    func refresh() async {
        readPermission = await permissions.photoReadStatus()
        guard readPermission.allowsPhotoBrowse else {
            isLoading = false
            return
        }
        isLoading = true
        await loadLibrary()
    }

    func requestReadAccess() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        readPermission = await permissions.requestPhotoReadAccess()
        if readPermission.allowsPhotoBrowse {
            await loadLibrary()
        } else {
            isLoading = false
        }
    }

    private func loadLibrary() async {
        let counts = await gallery.fetchCompositionCounts()
        var previews: [CompositionType: PHAsset] = [:]

        for type in CompositionType.allCases {
            let identifiers = await gallery.fetchPhotoIdentifiers(for: type)
            if let firstID = identifiers.first,
               let asset = fetchAsset(localIdentifier: firstID) {
                previews[type] = asset
            }
        }

        var recent: PHAsset?
        var recentComp = CompositionType.ruleOfThirds
        if let recentID = await gallery.fetchMostRecentAssetLocalIdentifier(),
           let asset = fetchAsset(localIdentifier: recentID) {
            recent = asset
            let metadata = await gallery.fetchAllCompositionMetadata()
            if let match = metadata.first(where: { $0.assetIdentifier == recentID }) {
                recentComp = match.composition
            }
        }

        compositionCounts = counts
        previewAssets = previews
        recentAsset = recent
        recentComposition = recentComp
        isLoading = false
    }

    private func fetchAsset(localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }
}
