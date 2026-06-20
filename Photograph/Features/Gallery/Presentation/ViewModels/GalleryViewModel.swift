//
//  GalleryViewModel.swift
//  Soolene
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

    var allAssets: [PHAsset] = []
    var assetsByComposition: [CompositionType: [PHAsset]] = [:]
    var assetCompositionMap: [String: CompositionType] = [:]

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
        
        // 1. Fetch all assets from custom album
        var loadedAssets: [PHAsset] = []
        if let fetchResult = await GalleryManager.shared.fetchAllPhotos() {
            fetchResult.enumerateObjects { asset, _, _ in
                loadedAssets.append(asset)
            }
        }
        
        // 2. Fetch all composition metadata to map local identifiers
        let metadata = await gallery.fetchAllCompositionMetadata()
        let metadataMap = Dictionary(uniqueKeysWithValues: metadata.map { ($0.assetIdentifier, $0.composition) })
        
        // 3. Group assets by composition
        var byComp: [CompositionType: [PHAsset]] = [:]
        for type in CompositionType.allCases {
            byComp[type] = []
        }
        for asset in loadedAssets {
            if let comp = metadataMap[asset.localIdentifier] {
                byComp[comp, default: []].append(asset)
            }
        }
        
        // Populate previewAssets (first asset in each composition)
        var previews: [CompositionType: PHAsset] = [:]
        for type in CompositionType.allCases {
            if let firstAsset = byComp[type]?.first {
                previews[type] = firstAsset
            }
        }
        
        self.allAssets = loadedAssets
        self.assetsByComposition = byComp
        self.assetCompositionMap = metadataMap
        self.compositionCounts = counts
        self.previewAssets = previews
        
        self.recentAsset = loadedAssets.first
        if let recentID = loadedAssets.first?.localIdentifier,
           let match = metadata.first(where: { $0.assetIdentifier == recentID }) {
            self.recentComposition = match.composition
        }
        
        isLoading = false
    }

    private func fetchAsset(localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    func asset(localIdentifier: String) -> PHAsset? {
        fetchAsset(localIdentifier: localIdentifier)
    }
}
