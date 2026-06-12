//
//  VisionAnalyzing.swift
//  Photograph
//

import AVFoundation
import CoreMedia
import Foundation

/// Composition analysis from camera frames (spatial AR or classic AV).
protocol VisionAnalyzing: AnyObject {
    var usesSpatialTracking: Bool { get set }
    var isMLEnabled: Bool { get set }
    var deviceRollDegrees: Double? { get set }
    var onAnalysisUpdated: ((CompositionAnalysis) -> Void)? { get set }
    var onMLSuggestionReady: (([CompositionPrediction]) -> Void)? { get set }

    func processSpatialFramePacket(_ packet: SpatialFramePacket)
    func processFrame(_ sampleBuffer: CMSampleBuffer, depthData: AVDepthData?)
    func pinSubject(at normalisedPoint: CGPoint)
    func clearPinnedSubject()
    func shouldProcessVisionFrame() -> Bool
    func prepareForCapture() async
    func resumeAfterCapture()
}
