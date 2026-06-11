//
//  PixelBufferCopier.swift
//  Photograph
//
//  Creates an independent copy of a CVPixelBuffer for safe async Vision processing.
//

import CoreVideo

enum PixelBufferCopier {
    /// Returns a deep copy of `source`, or nil if allocation fails.
    static func copy(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let format = CVPixelBufferGetPixelFormatType(source)

        var destination: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &destination
        )
        guard status == kCVReturnSuccess, let dest = destination else { return nil }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(dest, [])
        defer {
            CVPixelBufferUnlockBaseAddress(dest, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        let planeCount = CVPixelBufferGetPlaneCount(source)
        if planeCount == 0 {
            guard let srcBase = CVPixelBufferGetBaseAddress(source),
                  let dstBase = CVPixelBufferGetBaseAddress(dest)
            else { return nil }

            let bytesPerRow = CVPixelBufferGetBytesPerRow(source)
            let height = CVPixelBufferGetHeight(source)
            memcpy(dstBase, srcBase, bytesPerRow * height)
        } else {
            for plane in 0..<planeCount {
                guard let srcBase = CVPixelBufferGetBaseAddressOfPlane(source, plane),
                      let dstBase = CVPixelBufferGetBaseAddressOfPlane(dest, plane)
                else { return nil }

                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(source, plane)
                let planeHeight = CVPixelBufferGetHeightOfPlane(source, plane)
                memcpy(dstBase, srcBase, bytesPerRow * planeHeight)
            }
        }

        return dest
    }
}
