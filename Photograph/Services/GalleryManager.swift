//
//  GalleryManager.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import Foundation
import Photos
import UIKit

/// Manages saving and reading photos in a custom "Photograph" album.
/// Photos are saved to both Camera Roll and the custom album for in-app gallery.
actor GalleryManager {
    static let shared = GalleryManager()

    private let albumName = "Photograph"

    // MARK: - Save Photo

    /// Saves photo data to Camera Roll AND the custom "Photograph" album.
    /// - Parameters:
    ///   - photoData: Raw JPEG data including EXIF metadata
    ///   - composition: The detected composition type to store as metadata
    func savePhoto(_ photoData: Data, composition: CompositionType) async throws {
        // Check authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard newStatus == .authorized || newStatus == .limited else {
                throw GalleryError.permissionDenied
            }
        } else if status != .authorized && status != .limited {
            throw GalleryError.permissionDenied
        }

        // Get or create album
        let album = try await getOrCreateAlbum()

        var localIdentifier = ""

        // Save photo to album
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: photoData, options: nil)

            // Add to custom album
            if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
               let placeholder = request.placeholderForCreatedAsset
            {
                localIdentifier = placeholder.localIdentifier
                albumChangeRequest.addAssets([placeholder] as NSFastEnumeration)
            }
        }

        // Save composition metadata locally using the actual asset identifier
        await saveCompositionMetadata(composition: composition, localIdentifier: localIdentifier)
    }

    // MARK: - Fetch Photos

    /// Fetches all photos from the "Photograph" album.
    func fetchAllPhotos() async -> PHFetchResult<PHAsset>? {
        guard let album = findAlbum() else { return nil }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(in: album, options: options)
    }

    /// Returns the count of photos per composition type.
    func fetchCompositionCounts() async -> [CompositionType: Int] {
        let metadata = loadAllMetadata()
        var counts: [CompositionType: Int] = [:]
        for type in CompositionType.allCases {
            counts[type] = metadata.filter { $0.composition == type }.count
        }
        return counts
    }

    /// Returns photo identifiers for a specific composition.
    func fetchPhotoIdentifiers(for composition: CompositionType) -> [String] {
        let metadata = loadAllMetadata()
        return metadata
            .filter { $0.composition == composition }
            .map { $0.assetIdentifier }
    }

    // MARK: - Album Management

    private func getOrCreateAlbum() async throws -> PHAssetCollection {
        if let existing = findAlbum() { return existing }

        var albumID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            albumID = request.placeholderForCreatedAssetCollection.localIdentifier
        }

        guard let id = albumID else { throw GalleryError.saveFailed }
        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
        guard let album = result.firstObject else { throw GalleryError.saveFailed }
        return album
    }

    private nonisolated func findAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumName)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).firstObject
    }

    // MARK: - Local Metadata (JSON file)

    /// Simple local storage for composition metadata since EXIF doesn't support custom fields easily.
    private struct PhotoMetadata: Codable {
        let assetIdentifier: String
        let composition: CompositionType
        let timestamp: Date
    }

    private var metadataURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("photograph_metadata.json")
    }

    private func saveCompositionMetadata(composition: CompositionType, localIdentifier: String) {
        var metadata = loadAllMetadata()

        let entry = PhotoMetadata(
            assetIdentifier: localIdentifier,
            composition: composition,
            timestamp: Date()
        )
        metadata.append(entry)

        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }

    private nonisolated func loadAllMetadata() -> [PhotoMetadata] {
        guard let data = try? Data(contentsOf: {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent("photograph_metadata.json")
        }()) else { return [] }
        return (try? JSONDecoder().decode([PhotoMetadata].self, from: data)) ?? []
    }
}

// MARK: - Errors

enum GalleryError: LocalizedError {
    case saveFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Could not save the photo. Please try again."
        case .permissionDenied:
            return "Photo Library permission required. Please enable in Settings."
        }
    }
}
