//
//  GalleryRepository.swift
//  Photograph
//

import UIKit

/// Persistence boundary for captured photos.
protocol GalleryRepository: Sendable {
    func savePhoto(_ photoData: Data, composition: CompositionType) async throws
    func fetchCompositionCounts() async -> [CompositionType: Int]
    func fetchPhotoIdentifiers(for composition: CompositionType) async -> [String]
    func fetchAllCompositionMetadata() async -> [GalleryManager.PhotoMetadata]
}
