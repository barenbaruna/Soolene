//
//  DepthAnalyzer.swift
//  Photograph
//
//  Utility for extracting distance in meters from an AVDepthData object.
//  Handles coordinate mapping from normalized UI space to Depth Map pixel space.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import AVFoundation
import CoreGraphics
import CoreVideo

struct DepthAnalyzer {

    /// Extracts the depth in meters at the given normalized point (0-1).
    ///
    /// Handles both Float32 and Float16 depth formats. If the source data is Float16,
    /// it is converted to Float32 using Apple's `AVDepthData.converting(toDepthDataType:)` API
    /// before reading. This ensures compatibility with all LiDAR-equipped devices.
    ///
    /// Extracts depth in meters from an ARKit scene-depth map (`ARDepthData.depthMap`).
    static func extractDepth(at normalizedPoint: CGPoint, from depthMap: CVPixelBuffer) -> Float? {
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let px = Int(normalizedPoint.x * CGFloat(width))
        let py = Int(normalizedPoint.y * CGFloat(height))

        guard px >= 0, px < width, py >= 0, py < height else { return nil }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let format = CVPixelBufferGetPixelFormatType(depthMap)

        let value: Float
        if format == kCVPixelFormatType_DepthFloat32 {
            let rowPtr = baseAddress.advanced(by: py * bytesPerRow)
            let pointer = rowPtr.assumingMemoryBound(to: Float32.self)
            value = pointer[px]
        } else if format == kCVPixelFormatType_DepthFloat16 {
            let rowPtr = baseAddress.advanced(by: py * bytesPerRow)
            let pointer = rowPtr.assumingMemoryBound(to: UInt16.self)
            value = float16ToFloat32(pointer[px])
        } else {
            return nil
        }

        if value.isNaN || value <= 0 { return nil }
        return value
    }

    /// Returns nil if depth cannot be read, the point is out of bounds, or the pixel is NaN.
    static func extractDepth(at normalizedPoint: CGPoint, from depthData: AVDepthData) -> Float? {
        // Normalise to Float32 depth format if needed
        let normalised = normaliseToFloat32(depthData)
        let depthMap = normalised.depthDataMap

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let px = Int(normalizedPoint.x * CGFloat(width))
        let py = Int(normalizedPoint.y * CGFloat(height))

        guard px >= 0, px < width, py >= 0, py < height else {
            return nil
        }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }

        // Use bytesPerRow for correct stride (rows may be padded)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let rowPtr = baseAddress.advanced(by: py * bytesPerRow)
        let pointer = rowPtr.assumingMemoryBound(to: Float32.self)
        let value = pointer[px]

        if value.isNaN || value <= 0 { return nil }

        // After normalisation, the format is always DepthFloat32 (meters)
        return value
    }

    // MARK: - Format Normalisation

    /// Converts the depth data to DepthFloat32 if it is in any other format.
    /// If already Float32 depth, returns the original data unchanged.
    private static func normaliseToFloat32(_ depthData: AVDepthData) -> AVDepthData {
        let currentType = depthData.depthDataType

        // Already in the desired format
        if currentType == kCVPixelFormatType_DepthFloat32 {
            return depthData
        }

        // Convert disparity to depth, or Float16 to Float32
        let targetType: OSType = kCVPixelFormatType_DepthFloat32
        if depthData.availableDepthDataTypes.contains(targetType) {
            return depthData.converting(toDepthDataType: targetType)
        }

        // If DepthFloat32 is not available, return as-is (will fail gracefully)
        return depthData
    }

    private static func float16ToFloat32(_ value: UInt16) -> Float {
        Float(Float16(bitPattern: value))
    }
}
