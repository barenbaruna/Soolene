//
//  LiveGalleryRepository.swift
//  Photograph
//

import Foundation
import Photos

/// Default `GalleryRepository` backed by `GalleryManager`.
struct LiveGalleryRepository: GalleryRepository {
    private let manager: GalleryManager

    init(manager: GalleryManager = .shared) {
        self.manager = manager
    }

    func savePhoto(_ photoData: Data, composition: CompositionType) async throws -> String {
        try await manager.savePhoto(photoData, composition: composition)
    }

    func fetchCompositionCounts() async -> [CompositionType: Int] {
        await manager.fetchCompositionCounts()
    }

    func fetchPhotoIdentifiers(for composition: CompositionType) async -> [String] {
        await manager.fetchPhotoIdentifiers(for: composition)
    }

    func fetchAllCompositionMetadata() async -> [GalleryManager.PhotoMetadata] {
        await manager.fetchAllCompositionMetadata()
    }

    func fetchMostRecentAssetLocalIdentifier() async -> String? {
        await manager.fetchAllPhotos()?.firstObject?.localIdentifier
    }
}
