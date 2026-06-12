//
//  CompositionPhotoListViewModel.swift
//  Photograph
//

import Photos
import SwiftUI

@MainActor
@Observable
final class CompositionPhotoListViewModel {
    let composition: CompositionType
    var assets: [PHAsset] = []
    var isLoading = true

    private let gallery: GalleryRepository

    init(
        composition: CompositionType,
        gallery: GalleryRepository = LiveGalleryRepository()
    ) {
        self.composition = composition
        self.gallery = gallery
    }

    func loadPhotos() async {
        let identifiers = await gallery.fetchPhotoIdentifiers(for: composition)
        guard !identifiers.isEmpty else {
            isLoading = false
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var result: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            result.append(asset)
        }
        result.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        assets = result
        isLoading = false
    }
}
