//
//  VisionAnalysisProcessor.swift
//  Photograph
//

import AVFoundation
import Foundation
import UIKit

/// Shared analysis finalization and ML hysteresis for spatial and classic pipelines.
struct VisionAnalysisProcessor {

    var usesSpatialTracking: Bool
    var isMLEnabled: Bool
    var userGuidanceActive: Bool
    var deviceRollDegrees: Double?
    var activeAspectRatio: AspectRatioMode
    /// Physical device orientation read from UIDevice — independent of system orientation lock.
    var activeDeviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    var hysteresisComposition: CompositionType?
    var hysteresisConfidence: Float = 0
    var hysteresisFrameCount = 0

    private let scanningFilter = OneEuroPointFilter(minCutoff: 0.8, beta: 0.005)
    private let guidanceFilter = OneEuroPointFilter(minCutoff: 0.1, beta: 0.001)

    mutating func buildFinalAnalysis(
        from input: CompositionAnalysis,
        depthData: AVDepthData?
    ) -> CompositionAnalysis {
        var updated = input
        updated.sceneGeometry.deviceRollDegrees = deviceRollDegrees

        if let rawSubject = AlignmentAnalyzer.resolveSubjectPoint(from: updated.sceneGeometry, depthData: depthData) {
            let smoothedSubject: CGPoint
            if usesSpatialTracking, updated.sceneGeometry.lockedTargetPoint != nil {
                smoothedSubject = rawSubject
            } else {
                let activeFilter = (updated.sceneGeometry.lockedTargetPoint != nil) ? guidanceFilter : scanningFilter
                smoothedSubject = activeFilter.filter(rawSubject)
            }
            updated.sceneGeometry.smoothedSubjectPoint = smoothedSubject

            if updated.sceneGeometry.lockedTargetPoint == nil, !userGuidanceActive {
                if let newTarget = AlignmentAnalyzer.targetPoint(
                    for: updated.detectedComposition,
                    subject: smoothedSubject,
                    geometry: updated.sceneGeometry,
                    aspectRatio: activeAspectRatio
                ) {
                    updated.sceneGeometry.lockedTargetPoint = newTarget
                }
            }
        } else {
            scanningFilter.reset()
            guidanceFilter.reset()
            updated.sceneGeometry.smoothedSubjectPoint = nil
        }

        if isMLEnabled, !userGuidanceActive, !updated.mlPredictions.isEmpty {
            let composition = applyMLHysteresis(
                predictions: updated.mlPredictions,
                current: updated.detectedComposition
            )
            if composition != updated.detectedComposition {
                updated.sceneGeometry.lockedTargetPoint = nil
            }
            updated.detectedComposition = composition
            if let technique = GuidanceEngine.pickBest(
                predictions: updated.mlPredictions,
                geometry: updated.sceneGeometry
            ) {
                updated.activeTechnique = CompositionTechnique(
                    composition: composition,
                    tip: technique.tip
                )
            }
        }

        let offsetResult = AlignmentAnalyzer.computeSubjectOffset(
            for: updated.detectedComposition,
            geometry: updated.sceneGeometry,
            depthData: depthData,
            aspectRatio: activeAspectRatio,
            orientation: activeDeviceOrientation,
            wasPerfect: input.isCompositionPerfect
        )
        updated.subjectOffset = offsetResult.vector
        updated.isCompositionPerfect = offsetResult.isPerfect
        updated.guidanceDistance = offsetResult.guidanceDistance

        updated.sceneAlignmentScore = AlignmentAnalyzer.computeSceneAlignmentScore(
            for: updated.detectedComposition,
            geometry: updated.sceneGeometry,
            isPerfect: offsetResult.isPerfect,
            depthData: depthData,
            aspectRatio: activeAspectRatio,
            orientation: activeDeviceOrientation
        )

        return updated
    }

    mutating func resetFilters() {
        scanningFilter.reset()
        guidanceFilter.reset()
    }

    mutating func resetHysteresis() {
        hysteresisComposition = nil
        hysteresisConfidence = 0
        hysteresisFrameCount = 0
    }

    private mutating func applyMLHysteresis(
        predictions: [CompositionPrediction],
        current: CompositionType
    ) -> CompositionType {
        guard let top = predictions.first else { return current }

        if top.type == current || top.type == hysteresisComposition {
            hysteresisFrameCount = 0
            hysteresisComposition = top.type
            hysteresisConfidence = top.confidence
            return top.type
        }

        let delta = top.confidence - hysteresisConfidence
        if hysteresisComposition == nil || delta >= GuidanceEngine.mlHysteresisMinDelta {
            hysteresisComposition = top.type
            hysteresisConfidence = top.confidence
            hysteresisFrameCount = 0
            return top.type
        }

        hysteresisFrameCount += 1
        if hysteresisFrameCount >= GuidanceEngine.mlHysteresisFrames {
            hysteresisComposition = top.type
            hysteresisConfidence = top.confidence
            hysteresisFrameCount = 0
            return top.type
        }

        return hysteresisComposition ?? current
    }
}
